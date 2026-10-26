# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Одна и та же таблица XOR при удержанном входе.
    #
    # Обратный проход идёт сквозь forward: вход не отпускается settle_steps тактов,
    # ошибка снимается с итогового выхода. Куб и центр звезды разделяют четыре строки.
    # У кольца оба входа стоят на одном проводе, и все четыре строки сходятся
    # к одной активации.
    class HeldXor
      EPOCHS = 200
      RATE = 0.3
      SEED = 1
      INPUTS = [[-1.0, -1.0], [-1.0, 1.0], [1.0, -1.0], [1.0, 1.0]].freeze
      TARGETS = [[-1.0], [1.0], [1.0], [-1.0]].freeze

      def self.run
        cube = train(:cube)
        star = train(:star)
        ring = train(:ring)
        success = separated?(cube) && separated?(star) && collapsed?(ring)

        Result.new(
          name: "Удержанный XOR",
          success: success,
          summary: format(
            "куб MSE %.4f, звезда MSE %.4f, кольцо %.2f %.2f %.2f %.2f",
            cube[:mse], star[:mse], *ring[:outputs]
          ),
          details: { cube: cube, star: star, ring: ring }
        )
      end

      def self.train(kind)
        network = build(kind)
        before = network.mean_squared_error(INPUTS, TARGETS)
        stats = network.train_settled(INPUTS, TARGETS, epochs: EPOCHS, learning_rate: RATE)
        outputs = INPUTS.map { |input| network.forward(input, record: false).first }
        {
          before: before,
          mse: stats[:final_mse],
          accuracy: Tasks.bipolar_accuracy(network, INPUTS, TARGETS),
          outputs: outputs
        }
      end

      def self.separated?(row)
        row[:accuracy] == 1.0 && row[:mse] < 0.02
      end

      def self.collapsed?(row)
        spread = row[:outputs].max - row[:outputs].min
        row[:accuracy] < 1.0 && row[:mse] > 0.5 && spread < 0.2
      end

      def self.build(kind)
        common = { activation: :tanh, settle_steps: 4, seed: SEED, log: false }
        case kind
        when :cube
          Topologies::Cube.new(common.merge(input_indices: [0, 1], output_indices: [7]))
        when :star
          Topologies::Star.new(common.merge(input_indices: [1, 2], output_indices: [0]))
        when :ring
          Topologies::Ring.new(common.merge(size: 6, input_indices: [0, 1], output_indices: [3]))
        else
          raise ArgumentError, "Неизвестный участник #{kind}"
        end
      end
    end
  end
end
