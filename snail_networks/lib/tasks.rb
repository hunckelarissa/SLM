# frozen_string_literal: true

module SnailNetwork
  # Одинаковые задачи для всех топологий.
  # Цели биполярные (−1 и +1): порог tanh лежит посередине, а не на асимптоте.
  module Tasks
    module_function

    # Все двоичные векторы длины input_size в порядке масок.
    # @return [Array<Array<Float>>]
    def binary_patterns(input_size)
      size = Integer(input_size)
      raise ArgumentError, "input_size должен быть от 1 до 12" unless size.between?(1, 12)

      (0...(2**size)).map do |mask|
        Array.new(size) { |bit| ((mask >> bit) & 1).to_f }
      end
    end

    # Выходы чередуют разные булевы функции, чтобы два выхода не требовали
    # одну и ту же метку (у двух бит XOR совпадает с чётностью).
    #   0 — XOR первых двух, 1 — AND, 2 — чётность всех, 3 — OR.
    # level :unit — входы 0 и 1, :sign — те же строки как −1 и +1.
    # Метки считаются по битам, не по знаковому уровню: −1 не должен стать «нулём».
    # @return [Array(Array<Array<Float>>, Array<Array<Float>>)]
    def parity_bipolar(input_size, output_size, level: :unit)
      output_count = Integer(output_size)
      raise ArgumentError, "output_size должен быть положительным" if output_count <= 0

      bits = binary_patterns(input_size)
      inputs = case level.to_sym
               when :unit
                 bits
               when :sign
                 bits.map { |row| row.map { |bit| bit.zero? ? -1.0 : 1.0 } }
               else
                 raise ArgumentError, "Уровень входа #{level.inspect} не unit и не sign"
               end
      targets = bits.map { |row| bipolar_labels(row, output_count) }
      [inputs, targets]
    end

    # @return [Array<Float>]
    def bipolar_labels(input, output_size)
      bits = input.map(&:to_i)
      positive = 1.0
      negative = -1.0
      single = bits[0].zero? ? negative : positive
      xor = bits.size >= 2 ? (bits[0] == bits[1] ? negative : positive) : single
      and_gate = bits.size >= 2 ? (bits[0] == 1 && bits[1] == 1 ? positive : negative) : single
      parity = bits.sum.odd? ? positive : negative
      or_gate = bits.any? { |bit| bit == 1 } ? positive : negative
      functions = [xor, and_gate, parity, or_gate]
      Array.new(output_size) { |index| functions[index % functions.size] }
    end

    # Импульс амплитуды amplitude в нулевом кадре должен появиться на единственном
    # выходе ровно через delay тактов. До этого цель — ноль.
    # @return [Array(Array<Array<Float>>, Array<Array<Float>>)]
    # +peak+ задаёт цель на такте задержки отдельно от амплитуды входа.
    # +tail+ дописывает тихие кадры после эха: вход и цель там нули.
    # Для tanh цель около 0.5 достижима, а ±1 лежит на асимптоте.
    def impulse(delay:, amplitude:, peak: nil, tail: 0)
      lag = Integer(delay)
      extra = Integer(tail)
      raise ArgumentError, "delay должен быть неотрицательным" if lag.negative?
      raise ArgumentError, "tail должен быть неотрицательным" if extra.negative?

      height = amplitude.to_f
      response = peak.nil? ? height : peak.to_f
      length = lag + 1 + extra
      frames = Array.new(length) { |time| [time.zero? ? height : 0.0] }
      targets = Array.new(length) { |time| [time == lag ? response : 0.0] }
      [frames, targets]
    end

    # Три эпизода сдвига: положительный импульс, отрицательный и тишина.
    # @return [Array]
    def shift_episodes(delay:, amplitude: 1.0, peak: nil, tail: 0)
      [amplitude, -amplitude, 0.0].map do |value|
        response = if peak.nil?
                     nil
                   elsif value.negative?
                     -peak.to_f.abs
                   elsif value.zero?
                     0.0
                   else
                     peak.to_f.abs
                   end
        impulse(delay: delay, amplitude: value, peak: response, tail: tail)
      end
    end

    # Импульс обходит кольцо длины steps-1 и возвращается во входной нейрон.
    # invert: true — цель на последнем кадре меняет знак (лента Мёбиуса).
    # На нулевом кадре цель совпадает с входом: нейрон и принимает, и отдаёт.
    # @return [Array]
    def loop_episodes(steps:, invert:)
      length = Integer(steps)
      raise ArgumentError, "steps должен быть не меньше 2" if length < 2

      [1.0, -1.0, 0.0].map do |amplitude|
        frames = Array.new(length) { |time| [time.zero? ? amplitude : 0.0] }
        targets = Array.new(length) { [0.0] }
        targets[0][0] = amplitude
        targets[length - 1][0] = invert ? -amplitude : amplitude
        [frames, targets]
      end
    end

    # Два импульса одной амплитуды: в нулевом кадре и ещё через gap кадров.
    # Ряд длится, пока второй импульс не получит те же delay тактов, что и первый.
    # @return [Array<Array<Float>>]
    def paired_frames(delay:, gap:, amplitude: 1.0)
      lag = Integer(delay)
      spacing = Integer(gap)
      raise ArgumentError, "delay должен быть положительным" unless lag.positive?
      raise ArgumentError, "gap должен быть положительным" unless spacing.positive?

      height = amplitude.to_f
      Array.new(lag + spacing + 1) { |time| [time.zero? || time == spacing ? height : 0.0] }
    end

    # Доля выходов, у которых знак совпал с целью.
    # @return [Float]
    def bipolar_accuracy(network, inputs, targets)
      correct = 0
      total = 0
      inputs.each_with_index do |input, index|
        output = network.forward(input, record: false)
        output.each_with_index do |value, output_index|
          total += 1
          correct += 1 if (value >= 0) == (targets[index][output_index] >= 0)
        end
      end
      return 0.0 if total.zero?

      correct.to_f / total
    end
  end
end
