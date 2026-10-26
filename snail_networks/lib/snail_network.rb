# frozen_string_literal: true

require "json"
require "csv"
require "logger"
require "stringio"
require "fileutils"
require_relative "neuron"
require_relative "synapse"
require_relative "visualizer"
require_relative "chart"

module SnailNetwork
  # Ошибка устройства графа: сигнал не доходит до выхода, индексы врут,
  # рёбра задублированы. Сеть с такой топологией нельзя честно обучать.
  class TopologyError < StandardError; end

  # Базовый класс всех «улиток».
  #
  # Обновление синхронное и идёт несколько тактов (settle_steps). Это один
  # и тот же механизм и для слоёв, и для колец.
  #
  # Внешний вход не затирает нейрон навсегда:
  #   * если у входного нейрона нет входящих синапсов, он пропускает значение
  #     как есть (классический вход слоя);
  #   * если входящие есть, активация равна f(рекуррентная сумма + смещение + вход).
  #     Поэтому кольцо, звезда и лента Мёбиуса действительно замыкаются.
  #
  # Подкласс реализует build_topology, default_input_indices и default_output_indices.
  # Индексы можно переопределить ключами конфигурации input_indices / output_indices.
  class SnailNetwork
    attr_reader :neurons, :synapses, :config, :logger, :activity_log, :rng

    # @param config [Hash]
    def initialize(config = {})
      @config = normalize_config(config)
      @logger = build_logger
      @rng = build_rng
      @activity_log = []
      @neurons = []
      @synapses = []
      build_topology
      validate_topology!
    end

    def build_topology
      raise NotImplementedError, "#{self.class} должен реализовать #build_topology"
    end

    def default_input_indices
      raise NotImplementedError, "#{self.class} должен реализовать #default_input_indices"
    end

    def default_output_indices
      raise NotImplementedError, "#{self.class} должен реализовать #default_output_indices"
    end

    # @return [Array<Integer>]
    def input_indices
      resolve_indices(:input_indices) { default_input_indices }
    end

    # @return [Array<Integer>]
    def output_indices
      resolve_indices(:output_indices) { default_output_indices }
    end

    # Удержать вход и прогнать settle_steps синхронных обновлений.
    #
    # @param inputs [Array<Numeric>]
    # @param steps [Integer, nil]
    # @param record [Boolean] писать ли ряд активаций
    # @param append [Boolean] дописывать к уже накопленному ряду
    # @return [Array<Float>]
    def forward(inputs, steps: nil, record: true, append: false)
      steps ||= @config[:settle_steps].to_i
      validate_vector!(inputs, input_indices.size, "входов")
      external = external_map(inputs)

      reset_neurons
      prepare_log(record, append)
      seed_inputs(external)
      steps.times do |step|
        update_all(external)
        record_activity(step) if record
      end
      output_activations
    end

    # Один синхронный такт без сброса состояния.
    # Последовательность таких тактов — это память кольца и линии задержки.
    #
    # @param inputs [Array<Numeric>]
    # @param record [Boolean]
    # @return [Array<Float>]
    def step(inputs, record: false)
      validate_vector!(inputs, input_indices.size, "входов")
      update_all(external_map(inputs))
      record_activity(@activity_log.size) if record
      output_activations
    end

    # Покадровая подача входа. Состояние переносится между кадрами.
    #
    # @param frames [Array<Array<Numeric>>]
    # @param record [Boolean]
    # @param append [Boolean]
    # @return [Array<Array<Float>>] выход после каждого кадра
    def forward_sequence(frames, record: false, append: false)
      raise ArgumentError, "Последовательность кадров пуста" if frames.nil? || frames.empty?

      reset_neurons
      prepare_log(record, append)
      frames.each_with_index.map do |frame, step_index|
        validate_vector!(frame, input_indices.size, "входов")
        update_all(external_map(frame))
        record_activity(step_index) if record
        output_activations
      end
    end

    # Свободная релаксация: начальное поле активаций растекается по связям
    # без внешнего входа. Нужна решёткам и другим пространственным сетям.
    #
    # @param initial [Array<Numeric>] активация каждого нейрона
    # @param steps [Integer, nil]
    # @param record [Boolean]
    # @return [Array<Float>]
    def relax(initial, steps: nil, record: false)
      steps ||= @config[:settle_steps].to_i
      validate_vector!(initial, neurons.size, "начальных активаций")
      reset_neurons
      prepare_log(record, false)
      initial.each_with_index { |value, idx| @neurons[idx].force_activation(value) }
      steps.times do |step|
        update_all({})
        record_activity(step) if record
      end
      activations
    end

    # Эволюционный поиск с элитизмом: потомок заменяет родителя только если
    # его MSE строго меньше. Иначе лучшие веса сохраняются.
    #
    # Вектор параметров — веса синапсов, затем смещения нейронов.
    #
    # @param inputs [Array<Array<Numeric>>]
    # @param targets [Array<Array<Numeric>>]
    # @param epochs [Integer, nil]
    # @return [Hash]
    def train(inputs, targets, epochs: nil)
      epochs = Integer(epochs || @config[:epochs] || 300)
      raise ArgumentError, "Число эпох не может быть отрицательным" if epochs.negative?

      validate_batch!(inputs, targets)
      population_size = Integer(@config[:population_size] || 30)
      raise ArgumentError, "Размер популяции должен быть положительным" if population_size <= 0

      mutation_rate = Float(@config[:mutation_rate] || 0.3)
      base_scale = Float(@config[:mutation_scale] || 0.5)
      decay = Float(@config[:mutation_decay] || 1.0)

      best_weights = weights
      best_mse = mean_squared_error(inputs, targets)
      history = []

      epochs.times do |epoch|
        scale = base_scale * (decay**epoch)

        population_size.times do
          candidate = best_weights.dup
          mutate!(candidate, mutation_rate, scale)
          set_weights(candidate)
          mse = mean_squared_error(inputs, targets)
          next unless mse < best_mse

          best_mse = mse
          best_weights = candidate
        end

        set_weights(best_weights)
        history << best_mse
        log_progress(epoch, epochs, best_mse) if (epoch % 50).zero?
        break if target_mse_reached?(best_mse)
      end

      set_weights(best_weights)
      { final_mse: best_mse, history: history }
    end

    # @param filename [String]
    def save_activity(filename)
      FileUtils.mkdir_p(File.dirname(filename))
      CSV.open(filename, "w") do |csv|
        csv << (["step"] + @neurons.map { |neuron| "n#{neuron.index}" })
        @activity_log.each do |step, row|
          csv << ([step] + row)
        end
      end
      @logger.info("Активность сохранена в #{filename}")
    end

    # График журнала активности в SVG. Пустой журнал не записывает файл.
    # @param filename [String]
    # @param title [String, nil]
    # @return [Boolean]
    def plot_activity(filename, title: nil)
      if @activity_log.empty?
        @logger.warn("Журнал активности пуст — график #{filename} не записан")
        return false
      end

      series = neurons.map do |neuron|
        {
          name: "n#{neuron.index}",
          values: @activity_log.map { |_step, row| row[neuron.index].to_f }
        }
      end
      Chart.line(series, filename, title: title || self.class.name.split("::").last)
      @logger.info("График активности сохранён в #{filename}")
      true
    end

    # Формат версии 2: синапсы и смещения. Старый файл-массив тоже читается.
    # @param filename [String]
    def save_weights(filename)
      FileUtils.mkdir_p(File.dirname(filename))
      payload = {
        version: 2,
        activation: @neurons.first&.activation_name&.to_s,
        synapses: synapses.each_with_index.map { |synapse, index| synapse.to_h.merge(index: index) },
        biases: neurons.map(&:bias)
      }
      File.write(filename, JSON.pretty_generate(payload))
      @logger.info("Веса сохранены в #{filename}")
    end

    # @param filename [String]
    def load_weights(filename)
      data = JSON.parse(File.read(filename))
      if data.is_a?(Array)
        apply_synapse_entries(data)
      else
        stored_activation = data["activation"]
        current_activation = @neurons.first&.activation_name&.to_s
        if stored_activation && current_activation && stored_activation != current_activation
          @logger.warn("В файле активация #{stored_activation}, у сети #{current_activation}")
        end
        apply_synapse_entries(data.fetch("synapses"))
        biases = data.fetch("biases")
        unless biases.size == neurons.size
          raise ArgumentError, "В файле #{biases.size} смещений, в сети #{neurons.size}"
        end

        neurons.each_with_index { |neuron, index| neuron.bias = biases[index].to_f }
      end
      @logger.info("Веса загружены из #{filename}")
    end

    # @param filename [String]
    # @return [Boolean]
    def visualize(filename)
      Visualizer.new(logger: @logger).visualize(self, filename)
    end

    # @return [Array<Float>]
    def output_activations
      output_indices.map { |index| @neurons[index].activation }
    end

    # @return [Array<Float>]
    def activations
      neurons.map(&:activation)
    end

    # Веса синапсов и следом смещения нейронов.
    # @return [Array<Float>]
    def weights
      synapses.map(&:weight) + neurons.map(&:bias)
    end

    # @param vector [Array<Numeric>]
    def set_weights(vector)
      expected = synapses.size + neurons.size
      unless vector.size == expected
        raise ArgumentError, "Ожидалось параметров: #{expected}, получено: #{vector.size}"
      end

      synapses.each_with_index { |synapse, index| synapse.weight = vector[index].to_f }
      neurons.each_with_index { |neuron, index| neuron.bias = vector[synapses.size + index].to_f }
    end

    # Обнулить веса и смещения, не трогая граф.
    def clear_parameters!
      synapses.each { |synapse| synapse.weight = 0.0 }
      neurons.each { |neuron| neuron.bias = 0.0 }
    end

    # @param from [Integer]
    # @param to [Integer]
    # @param weight [Numeric]
    # @return [Synapse]
    def set_synapse(from, to, weight)
      synapse = find_synapse(from, to)
      raise ArgumentError, "Нет синапса #{from}→#{to}" unless synapse

      synapse.weight = weight.to_f
      synapse
    end

    # Длина кратчайшего пути от любого входа до нейрона.
    # Ноль, если нейрон сам является входом. nil, если пути нет.
    # @param target_index [Integer]
    # @return [Integer, nil]
    def hop_distance(target_index)
      distances_from(input_indices)[target_index]
    end

    # Маршрут ровно из steps рёбер. Вершину можно посетить снова,
    # поэтому обход бывает длиннее кратчайшего пути.
    # @param from [Integer]
    # @param to [Integer]
    # @param steps [Integer]
    # @return [Boolean]
    def reachable_in?(from, to, steps)
      length = Integer(steps)
      raise ArgumentError, "Число шагов не может быть отрицательным" if length.negative?

      source = Integer(from)
      target = Integer(to)
      unless source.between?(0, neurons.size - 1) && target.between?(0, neurons.size - 1)
        raise ArgumentError, "Нейрон вне сети: #{from} → #{to}"
      end
      return source == target if length.zero?

      reach = Array.new(neurons.size, false)
      reach[source] = true
      length.times do
        nxt = Array.new(neurons.size, false)
        reach.each_with_index do |active, index|
          next unless active

          neurons[index].outgoing.each { |synapse| nxt[synapse.target.index] = true }
        end
        reach = nxt
      end
      reach[target]
    end

    # Длина кратчайшего пути между двумя нейронами. nil, если пути нет.
    # @return [Integer, nil]
    def distance_between(from, to)
      distances_from([checked_neuron(from)])[checked_neuron(to)]
    end

    # Простой путь ровно из steps рёбер: вершины не повторяются.
    # Такой путь можно оставить один, занулив остальные рёбра, и импульс
    # придёт точно в срок. Маршрут с повтором вершины всегда содержит более короткий.
    # @return [Boolean]
    def simple_path?(from, to, steps)
      length = Integer(steps)
      raise ArgumentError, "Число шагов не может быть отрицательным" if length.negative?

      source = checked_neuron(from)
      target = checked_neuron(to)
      return source == target if length.zero?

      search_simple_path(source, target, length, 1 << source)
    end

    # Как импульс длины steps может дойти из from в to.
    #   :wire        — кратчайший путь уже равен steps
    #   :detour      — есть более длинный простой путь, короткое ребро можно выключить
    #   :bottleneck  — дойти можно только маршрутом с повтором, и он тащит за собой короткий путь
    #   :none        — маршрута ровно такой длины нет
    # @return [Symbol]
    def route_kind(from, to, steps)
      length = Integer(steps)
      source = checked_neuron(from)
      target = checked_neuron(to)
      distance = distance_between(source, target)
      return :none if distance.nil? || !reachable_in?(source, target, length)
      return :wire if distance == length
      return :detour if simple_path?(source, target, length)

      :bottleneck
    end

    # Среднее по примерам от суммы квадратов ошибок по выходам.
    # @return [Float]
    def mean_squared_error(inputs, targets)
      validate_batch!(inputs, targets)
      total = inputs.each_with_index.sum do |input, index|
        output = forward(input, record: false)
        output.each_with_index.sum { |value, j| (value - targets[index][j].to_f)**2 }
      end
      total / inputs.size.to_f
    end

    # Среднее по эпизодам от суммы квадратов ошибок на каждом кадре.
    # Эпизод — пара [кадры входа, кадры цели] одинаковой длины.
    # @param episodes [Array<Array(Array, Array)>]
    # @return [Float]
    # +mask+ — вес кадра в ошибке. Ноль выключает прямой штраф на этом такте,
    # но градиент с будущих кадров сквозь него всё равно проходит.
    # Нулевая маска на середине петли оставляет слабый сигнал с возврата живым.
    def sequence_mse(episodes, mask: nil)
      validate_episodes!(episodes)
      total = episodes.sum do |frames, targets|
        outputs = forward_sequence(frames)
        squared_error(outputs, targets, normalize_mask(mask, frames.size))
      end
      total / episodes.size.to_f
    end

    # Обучение на последовательностях обратным распространением сквозь такты.
    # Состояние между кадрами переносится так же, как в forward_sequence.
    # Сквозь проходной вход градиент не идёт: там значение равно самому кадру.
    #
    # @param episodes [Array]
    # @param epochs [Integer, nil]
    # @param learning_rate [Float, nil]
    # @param mask [Array<Numeric>, nil] вес каждого кадра; nil — все кадры равны
    # @return [Hash]
    def train_sequence(episodes, epochs: nil, learning_rate: nil, mask: nil)
      epochs = Integer(epochs || @config[:epochs] || 300)
      raise ArgumentError, "Число эпох не может быть отрицательным" if epochs.negative?

      validate_episodes!(episodes)
      rate = Float(learning_rate || @config[:learning_rate] || 0.1)
      history = []

      epochs.times do |epoch|
        episodes.each_index.to_a.shuffle(random: @rng).each do |index|
          frames, targets = episodes[index]
          frame_mask = normalize_mask(mask, frames.size)
          backprop_through_time(frames, targets, rate, frame_mask)
        end
        mse = sequence_mse(episodes, mask: mask)
        history << mse
        log_progress(epoch, epochs, mse) if (epoch % 50).zero?
        break if target_mse_reached?(mse)
      end

      final_mse = history.empty? ? sequence_mse(episodes, mask: mask) : history.last
      { final_mse: final_mse, history: history }
    end

    # Статическая таблица через тот же такт, что и forward: вход удерживается
    # settle_steps раз, ошибка только на итоговом выходе. Поиск мутациями остаётся в train.
    #
    # @param inputs [Array<Array<Numeric>>]
    # @param targets [Array<Array<Numeric>>]
    # @param epochs [Integer, nil]
    # @param learning_rate [Float, nil]
    # @param steps [Integer, nil]
    # @return [Hash]
    def train_settled(inputs, targets, epochs: nil, learning_rate: nil, steps: nil)
      epochs = Integer(epochs || @config[:epochs] || 300)
      raise ArgumentError, "Число эпох не может быть отрицательным" if epochs.negative?

      validate_batch!(inputs, targets)
      depth = Integer(steps || @config[:settle_steps])
      raise ArgumentError, "Число тактов удержания должно быть положительным" unless depth.positive?

      rate = Float(learning_rate || @config[:learning_rate] || 0.1)
      history = []

      epochs.times do |epoch|
        inputs.each_index.to_a.shuffle(random: @rng).each do |index|
          backprop_settled(inputs[index], targets[index], depth, rate)
        end
        mse = mean_squared_error(inputs, targets)
        history << mse
        log_progress(epoch, epochs, mse) if (epoch % 50).zero?
        break if target_mse_reached?(mse)
      end

      final_mse = history.empty? ? mean_squared_error(inputs, targets) : history.last
      { final_mse: final_mse, history: history }
    end

    private

    def checked_neuron(index)
      neuron = Integer(index)
      return neuron if neuron.between?(0, neurons.size - 1)

      raise ArgumentError, "Нейрон вне сети: #{index}"
    end

    def search_simple_path(node, target, left, visited)
      neurons[node].outgoing.each do |synapse|
        nxt = synapse.target.index
        next unless (visited & (1 << nxt)).zero?
        return true if left == 1 && nxt == target
        next if left == 1
        return true if search_simple_path(nxt, target, left - 1, visited | (1 << nxt))
      end
      false
    end

    def normalize_config(config)
      raise ArgumentError, "Конфигурация должна быть хешем" unless config.is_a?(Hash)

      normalized = config.transform_keys { |key| key.respond_to?(:to_sym) ? key.to_sym : key }
      {
        settle_steps: 20,
        learning_rate: 0.1,
        mutation_rate: 0.3,
        mutation_scale: 0.5,
        mutation_decay: 1.0,
        population_size: 30,
        epochs: 300
      }.merge(normalized)
    end

    def build_logger
      enabled = @config.fetch(:log, true)
      enabled = false if enabled == false || enabled == "false"
      logger = Logger.new(enabled ? $stdout : StringIO.new)
      logger.level = Logger::INFO
      logger
    end

    def build_rng
      seed = @config[:seed]
      seed.nil? ? Random.new : Random.new(Integer(seed))
    end

    def resolve_indices(key)
      if @config.key?(key)
        Array(@config[key]).map { |value| Integer(value) }
      else
        yield
      end
    end

    def reset_neurons
      @neurons.each(&:reset)
    end

    def external_map(inputs)
      input_indices.each_with_index.to_h { |neuron_index, position| [neuron_index, inputs[position].to_f] }
    end

    def seed_inputs(external)
      external.each do |index, value|
        neuron = @neurons[index]
        if neuron.incoming.empty?
          neuron.force_activation(value)
        else
          neuron.activate(value)
        end
      end
    end

    def update_all(external)
      @neurons.each(&:compute_input_sum)
      @neurons.each_with_index do |neuron, index|
        if external.key?(index) && neuron.incoming.empty?
          neuron.force_activation(external[index])
        else
          neuron.activate(external.fetch(index, 0.0))
        end
      end
    end

    def prepare_log(record, append)
      return unless record

      @activity_log.clear unless append
    end

    def record_activity(step)
      @activity_log << [step, activations]
    end

    def mutate!(vector, rate, scale)
      vector.map! do |weight|
        if @rng.rand < rate
          weight + @rng.rand(-scale..scale)
        else
          weight
        end
      end
    end

    def find_synapse(source_idx, target_idx)
      synapses.find { |synapse| synapse.source.index == source_idx && synapse.target.index == target_idx }
    end

    def log_progress(epoch, total, mse)
      name = self.class.name.split("::").last
      @logger.info("[#{name}] эпоха #{epoch}/#{total}, MSE=#{format('%.4f', mse)}")
    end

    def target_mse_reached?(mse)
      return false unless @config.key?(:target_mse)

      mse <= Float(@config[:target_mse])
    end

    def validate_vector!(vector, expected, label)
      unless vector.respond_to?(:size) && vector.size == expected
        actual = vector.respond_to?(:size) ? vector.size : "не вектор"
        raise ArgumentError, "Ожидалось #{label}: #{expected}, получено: #{actual}"
      end

      vector.each_with_index do |value, index|
        next if value.is_a?(Numeric)

        raise ArgumentError, "#{label}, позиция #{index}: ожидалось число, получено #{value.inspect}"
      end
    end

    def validate_episodes!(episodes)
      raise ArgumentError, "Пустой набор эпизодов" if episodes.nil? || episodes.empty?

      episodes.each_with_index do |(frames, targets), index|
        raise ArgumentError, "Эпизод #{index} без кадров" if frames.nil? || frames.empty?
        unless targets.respond_to?(:size) && targets.size == frames.size
          raise ArgumentError, "Эпизод #{index}: число кадров и целей не совпадает"
        end

        frames.each_with_index do |frame, time|
          validate_vector!(frame, input_indices.size, "входов в эпизоде #{index}, кадр #{time}")
          validate_vector!(targets[time], output_indices.size, "целей в эпизоде #{index}, кадр #{time}")
        end
      end
    end

    def normalize_mask(mask, length)
      return nil if mask.nil?

      values = Array(mask).map(&:to_f)
      return values if values.size == length

      raise ArgumentError, "Маска длины #{values.size}, кадров #{length}"
    end

    def squared_error(outputs, targets, mask = nil)
      outputs.each_index.sum do |time|
        weight = mask.nil? ? 1.0 : mask[time]
        next 0.0 if weight.zero?

        weight * outputs[time].each_with_index.sum { |value, index| (value - targets[time][index].to_f)**2 }
      end
    end

    # Один проход BPTT. Градиент совпадает по знаку с SGD слоёв:
    # вес растёт, когда это уменьшает 1/2 суммы квадратов.
    def backprop_through_time(frames, targets, learning_rate, mask = nil)
      states = [activations_after_reset]
      frames.each { |frame| update_all(external_map(frame)); states << activations.dup }

      steps = frames.size
      width = neurons.size
      error = Array.new(steps) { Array.new(width, 0.0) }
      error_pre = Array.new(steps) { Array.new(width, 0.0) }

      (steps - 1).downto(0) do |time|
        frame_weight = mask.nil? ? 1.0 : mask[time]
        output_indices.each_with_index do |neuron_index, output_index|
          delta = targets[time][output_index].to_f - states[time + 1][neuron_index]
          error[time][neuron_index] += frame_weight * delta
        end

        neurons.each_index do |neuron_index|
          error_pre[time][neuron_index] = if passthrough?(neuron_index)
                                            0.0
                                          else
                                            error[time][neuron_index] * neurons[neuron_index].derivative_for(states[time + 1][neuron_index])
                                          end
        end

        next if time.zero?

        synapses.each do |synapse|
          source = synapse.source.index
          target = synapse.target.index
          error[time - 1][source] += error_pre[time][target] * synapse.effective_weight
        end
      end

      synapses.each do |synapse|
        gradient = steps.times.sum do |time|
          coeff = synapse.flip_sign ? -1.0 : 1.0
          error_pre[time][synapse.target.index] * states[time][synapse.source.index] * coeff
        end
        synapse.weight = (synapse.weight + (learning_rate * gradient).clamp(-1.0, 1.0)).clamp(-12.0, 12.0)
      end

      neurons.each_with_index do |neuron, neuron_index|
        next if passthrough?(neuron_index)

        gradient = error_pre.sum { |row| row[neuron_index] }
        neuron.bias = (neuron.bias + (learning_rate * gradient).clamp(-1.0, 1.0)).clamp(-12.0, 12.0)
      end
    end

    # Обратный проход сквозь forward: сначала посев входа, затем depth удержаний.
    # Посев не читает соседей, поэтому с него градиент идёт только в смещение
    # входного нейрона с обратной связью. Ошибка стоит на последнем такте.
    def backprop_settled(input, target, depth, learning_rate)
      external = external_map(input)
      states = [activations_after_reset]
      seed_inputs(external)
      states << activations.dup
      depth.times do
        update_all(external)
        states << activations.dup
      end

      width = neurons.size
      transitions = depth + 1
      error = Array.new(transitions) { Array.new(width, 0.0) }
      error_pre = Array.new(transitions) { Array.new(width, 0.0) }
      output_indices.each_with_index do |neuron_index, output_index|
        error[depth][neuron_index] += target[output_index].to_f - states[depth + 1][neuron_index]
      end

      depth.downto(0) do |time|
        neurons.each_index do |neuron_index|
          error_pre[time][neuron_index] = if settled_passthrough?(time, neuron_index)
                                            0.0
                                          else
                                            error[time][neuron_index] * neurons[neuron_index].derivative_for(states[time + 1][neuron_index])
                                          end
        end
        next if time.zero?

        synapses.each do |synapse|
          error[time - 1][synapse.source.index] += error_pre[time][synapse.target.index] * synapse.effective_weight
        end
      end

      synapses.each do |synapse|
        gradient = (1..depth).sum do |time|
          coeff = synapse.flip_sign ? -1.0 : 1.0
          error_pre[time][synapse.target.index] * states[time][synapse.source.index] * coeff
        end
        synapse.weight = (synapse.weight + (learning_rate * gradient).clamp(-1.0, 1.0)).clamp(-12.0, 12.0)
      end

      neurons.each_with_index do |neuron, neuron_index|
        next if passthrough?(neuron_index)

        gradient = error_pre.sum { |row| row[neuron_index] }
        neuron.bias = (neuron.bias + (learning_rate * gradient).clamp(-1.0, 1.0)).clamp(-12.0, 12.0)
      end
    end

    # На такте посева активация меняется только у входов. Проходной вход
    # и нейрон вне входа в этот момент от параметров не зависят.
    def settled_passthrough?(time, neuron_index)
      return true if passthrough?(neuron_index)
      return false unless time.zero?

      !input_indices.include?(neuron_index)
    end

    def activations_after_reset
      reset_neurons
      activations.dup
    end

    def passthrough?(index)
      input_indices.include?(index) && neurons[index].incoming.empty?
    end

    def validate_batch!(inputs, targets)
      raise ArgumentError, "Пустой обучающий набор" if inputs.nil? || inputs.empty?
      raise ArgumentError, "Число примеров и целей не совпадает" unless targets&.size == inputs.size

      inputs.each_with_index do |input, index|
        validate_vector!(input, input_indices.size, "входов в примере #{index}")
        validate_vector!(targets[index], output_indices.size, "целей в примере #{index}")
      end
    end

    def validate_topology!
      raise TopologyError, "#{self.class} не содержит нейронов" if @neurons.empty?
      raise TopologyError, "#{self.class} не содержит синапсов" if @synapses.empty?

      expected_indices = (0...@neurons.size).to_a
      actual_indices = @neurons.map(&:index)
      unless actual_indices == expected_indices
        raise TopologyError, "#{self.class}: индексы нейронов должны идти подряд с нуля"
      end

      seen = {}
      @synapses.each do |synapse|
        source_index = synapse.source.index
        target_index = synapse.target.index
        unless @neurons[source_index].equal?(synapse.source) && @neurons[target_index].equal?(synapse.target)
          raise TopologyError, "#{self.class}: синапс ссылается на нейрон вне сети"
        end
        unless synapse.source.outgoing.include?(synapse) && synapse.target.incoming.include?(synapse)
          raise TopologyError, "#{self.class}: синапс не зарегистрирован у своих нейронов"
        end

        key = [source_index, target_index]
        if seen[key]
          raise TopologyError, "#{self.class}: дублирующийся синапс #{source_index}→#{target_index}"
        end

        seen[key] = true
      end

      check_endpoint_group(:input_size, input_indices, "вход")
      check_endpoint_group(:output_size, output_indices, "выход")

      distances = distances_from(input_indices)
      settle = @config[:settle_steps].to_i
      output_indices.each do |index|
        if input_indices.include?(index) && @neurons[index].incoming.empty?
          raise TopologyError, "#{self.class}: выход #{index} совпадает с проходным входом и не меняется"
        end

        distance = distances[index]
        if distance.nil?
          raise TopologyError, "#{self.class}: выход #{index} недостижим из входов #{input_indices}"
        end
        next if distance <= settle

        raise TopologyError,
              "#{self.class}: выход #{index} на расстоянии #{distance} тактов, settle_steps=#{settle}"
      end
    end

    def check_endpoint_group(config_key, indices, label)
      raise TopologyError, "#{self.class}: нет #{label}ов" if indices.empty?
      raise TopologyError, "#{self.class}: повторяющиеся индексы (#{label})" unless indices.uniq.size == indices.size

      indices.each do |index|
        unless index.is_a?(Integer) && index >= 0 && index < @neurons.size
          raise TopologyError, "#{self.class}: #{label} #{index} вне диапазона нейронов"
        end
      end

      return unless @config.key?(config_key)
      return if Integer(@config[config_key]) == indices.size

      raise TopologyError,
            "#{self.class}: #{config_key}=#{@config[config_key]}, но #{label}ов #{indices.size}"
    end

    def distances_from(sources)
      distances = {}
      queue = []
      sources.each do |index|
        next if distances.key?(index)

        distances[index] = 0
        queue << index
      end

      until queue.empty?
        current = queue.shift
        @neurons[current].outgoing.each do |synapse|
          nxt = synapse.target.index
          next if distances.key?(nxt)

          distances[nxt] = distances[current] + 1
          queue << nxt
        end
      end
      distances
    end

    def apply_synapse_entries(entries)
      unless entries.size == synapses.size
        raise ArgumentError, "В файле #{entries.size} синапсов, в сети #{synapses.size}"
      end

      entries.each do |entry|
        index = entry["index"]
        synapse = index.nil? ? find_synapse(entry["source"], entry["target"]) : synapses[index]
        raise ArgumentError, "Не найден синапс для записи #{entry.inspect}" unless synapse

        if entry["source"] && synapse.source.index != entry["source"]
          raise ArgumentError, "Синапс #{index} имеет source #{synapse.source.index}, в файле #{entry['source']}"
        end
        if entry["target"] && synapse.target.index != entry["target"]
          raise ArgumentError, "Синапс #{index} имеет target #{synapse.target.index}, в файле #{entry['target']}"
        end

        synapse.weight = entry["weight"].to_f
      end
    end
  end
end
