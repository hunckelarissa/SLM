# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Кольцо с двумя удержанными входами не доучивает XOR.
    #
    # Эволюция быстро находит три верных знака и стоит на месте: строка
    # «оба плюс» остаётся положительной, хотя цель −1. Обратный проход,
    # начатый с этих весов, четвёртый знак не переворачивает.
    class RingBasin
      EVOLUTION_EPOCHS = 120
      GRADIENT_EPOCHS = 60
      RATE = 0.2

      def self.run
        network = build
        evolved = snapshot(network)
        network.train(HeldXor::INPUTS, HeldXor::TARGETS, epochs: EVOLUTION_EPOCHS)
        after_evolution = snapshot(network)
        network.train_settled(
          HeldXor::INPUTS, HeldXor::TARGETS, epochs: GRADIENT_EPOCHS, learning_rate: RATE
        )
        after_gradient = snapshot(network)
        success = basin?(after_evolution) && basin?(after_gradient) &&
                  after_gradient[:accuracy] == after_evolution[:accuracy]

        Result.new(
          name: "Бассейн XOR на кольце",
          success: success,
          summary: format(
            "эволюция %.0f%% %s; градиент %.0f%% %s",
            after_evolution[:accuracy] * 100,
            pretty(after_evolution[:outputs]),
            after_gradient[:accuracy] * 100,
            pretty(after_gradient[:outputs])
          ),
          details: { start: evolved, evolution: after_evolution, gradient: after_gradient }
        )
      end

      def self.build
        Topologies::Ring.new(
          size: 6, input_indices: [0, 1], output_indices: [3],
          activation: :tanh, settle_steps: 4, seed: 4, population_size: 30, log: false
        )
      end

      def self.snapshot(network)
        outputs = HeldXor::INPUTS.map { |input| network.forward(input, record: false).first }
        {
          mse: network.mean_squared_error(HeldXor::INPUTS, HeldXor::TARGETS),
          accuracy: Tasks.bipolar_accuracy(network, HeldXor::INPUTS, HeldXor::TARGETS),
          outputs: outputs
        }
      end

      # Три знака верны, «оба плюс» остаётся положительным. Цель этой строки −1.
      def self.basin?(row)
        outputs = row[:outputs]
        row[:accuracy] == 0.75 && row[:mse] > 0.4 &&
          outputs[0] < -0.5 && outputs[1] > 0.1 && outputs[2] > 0.1 && outputs[3] > 0.1
      end

      def self.pretty(outputs)
        outputs.map { |value| format("% .2f", value) }.join(" ")
      end
    end
  end
end
