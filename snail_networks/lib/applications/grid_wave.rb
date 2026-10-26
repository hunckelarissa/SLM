# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Волна по сенсорной решётке 4×4.
    #
    # Импульс в клетке (0, 0) обязан дойти до (3, 3) ровно за манхэттенское
    # расстояние — 6 тактов — и никак не раньше. Это проверка задержки
    # локальной связи: так матрица датчиков отличает соседнюю вспышку от дальней.
    class GridWave
      SIDE = 4
      CORNER = (SIDE * SIDE) - 1
      DELAY = (SIDE - 1) * 2

      def self.run
        before = propagate(DELAY - 1)
        after = propagate(DELAY)
        first_step = propagate(1)
        arrived = after[CORNER].abs > 1e-6
        not_early = before[CORNER].abs < 1e-12
        neighbors = first_step[1].abs > 1e-6 && first_step[4].abs > 1e-6
        elsewhere_quiet = first_step.each_with_index.all? do |value, index|
          [0, 1, 4].include?(index) || value.abs < 1e-12
        end
        success = arrived && not_early && neighbors && elsewhere_quiet

        Result.new(
          name: "Волна по решётке (FlatSquare)",
          success: success,
          summary: format(
            "угол молчит на такте %d (%.3f) и отвечает на такте %d (%.3f)",
            DELAY - 1,
            before[CORNER],
            DELAY,
            after[CORNER]
          ),
          details: { before: before, after: after, grid: format_grid(after) }
        )
      end

      def self.propagate(steps)
        network = Topologies::FlatSquare.new(settle_steps: DELAY, activation: :tanh, seed: 1, log: false)
        network.synapses.each { |synapse| synapse.weight = 0.8 }
        network.neurons.each { |neuron| neuron.bias = 0.0 }
        initial = Array.new(network.neurons.size, 0.0)
        initial[0] = 1.0
        network.relax(initial, steps: steps)
      end

      def self.format_grid(values)
        values.each_slice(SIDE).map { |row| row.map { |value| format("%7.4f", value) }.join }.join("\n")
      end
    end
  end
end
