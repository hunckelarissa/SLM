# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Классическая полносвязная сеть из трёх слоёв без обратных связей.
    #
    # Размеры берутся из конфигурации (input_size, hidden_size, output_size
    # или массив layer_sizes). По умолчанию 3 → 6 → 2, как в исходном опыте.
    # Обучение — онлайн-SGD. Смещения есть у скрытого и выходного слоёв;
    # входной слой только пропускает вектор примера.
    class Layered < SnailNetwork
      include ConnectionHelpers

      INPUT_SIZE = 3
      HIDDEN_SIZE = 6
      OUTPUT_SIZE = 2

      def build_topology
        @layer_sizes = resolved_layer_sizes
        unless @layer_sizes.size == 3 && @layer_sizes.all? { |size| size.positive? }
          raise TopologyError, "Layered ждёт три положительных размера слоёв, получено #{@layer_sizes.inspect}"
        end

        @neurons = create_neurons(@layer_sizes.sum)
        @layer_ranges = []
        offset = 0
        @layer_sizes.each do |size|
          @layer_ranges << (offset...(offset + size))
          offset += size
        end

        connect_layers(0, 1)
        connect_layers(1, 2)
      end

      def default_input_indices
        @layer_ranges[0].to_a
      end

      def default_output_indices
        @layer_ranges[2].to_a
      end

      # @param inputs [Array<Array<Numeric>>]
      # @param targets [Array<Array<Numeric>>]
      # @param epochs [Integer, nil]
      # @return [Hash]
      def train(inputs, targets, epochs: nil)
        epochs = Integer(epochs || @config[:epochs] || 300)
        raise ArgumentError, "Число эпох не может быть отрицательным" if epochs.negative?

        validate_batch!(inputs, targets)
        learning_rate = Float(@config[:learning_rate] || 0.5)
        history = []

        epochs.times do |epoch|
          inputs.each_index.to_a.shuffle(random: @rng).each do |example|
            apply_sgd_step(inputs[example], targets[example], learning_rate)
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

      def resolved_layer_sizes
        if @config.key?(:layer_sizes)
          Array(@config[:layer_sizes]).map { |size| Integer(size) }
        else
          [
            Integer(@config.fetch(:input_size, INPUT_SIZE)),
            Integer(@config.fetch(:hidden_size, HIDDEN_SIZE)),
            Integer(@config.fetch(:output_size, OUTPUT_SIZE))
          ]
        end
      end

      def connect_layers(from_layer, to_layer)
        sources = @layer_ranges[from_layer]
        targets = @layer_ranges[to_layer]
        limit = Math.sqrt(6.0 / (sources.size + targets.size))
        sources.each do |source|
          targets.each do |target|
            connect(@neurons[source], @neurons[target], weight: @rng.rand(-limit..limit))
          end
        end
      end

      def hidden_indices
        @layer_ranges[1].to_a
      end

      def apply_sgd_step(input, target, learning_rate)
        output = forward(input, record: false)
        output_errors = output_indices.each_with_index.map do |index, output_index|
          (target[output_index].to_f - output[output_index]) * @neurons[index].activation_derivative
        end

        hidden_errors = hidden_indices.map do |hidden_index|
          arriving = output_indices.each_with_index.sum do |output_index, position|
            find_synapse(hidden_index, output_index).weight * output_errors[position]
          end
          arriving * @neurons[hidden_index].activation_derivative
        end

        hidden_indices.each_with_index do |hidden_index, hidden_position|
          output_indices.each_with_index do |output_index, output_position|
            synapse = find_synapse(hidden_index, output_index)
            gradient = learning_rate * output_errors[output_position] * @neurons[hidden_index].activation
            synapse.weight = (synapse.weight + gradient).clamp(-12.0, 12.0)
          end
          neuron = @neurons[hidden_index]
          neuron.bias = (neuron.bias + learning_rate * hidden_errors[hidden_position]).clamp(-12.0, 12.0)
        end

        input_indices.each do |input_index|
          hidden_indices.each_with_index do |hidden_index, hidden_position|
            synapse = find_synapse(input_index, hidden_index)
            gradient = learning_rate * hidden_errors[hidden_position] * @neurons[input_index].activation
            synapse.weight = (synapse.weight + gradient).clamp(-12.0, 12.0)
          end
        end

        output_indices.each_with_index do |output_index, output_position|
          neuron = @neurons[output_index]
          neuron.bias = (neuron.bias + learning_rate * output_errors[output_position]).clamp(-12.0, 12.0)
        end
      end
    end
  end
end
