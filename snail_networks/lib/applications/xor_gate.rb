# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Логический вентиль XOR на слоистой сети.
    #
    # Входы биполярные: одинаковые знаки дают −1, разные — +1.
    # Это эталон «топология здесь ни при чём»: слои и SGD должны выучить
    # таблицу целиком. Третий вход классической схемы 3→6→2 для вентиля не нужен,
    # поэтому пример собирает компактную сеть 2→6→1.
    class XorGate
      INPUTS = [[-1.0, -1.0], [-1.0, 1.0], [1.0, -1.0], [1.0, 1.0]].freeze
      TARGETS = [[-1.0], [1.0], [1.0], [-1.0]].freeze

      def self.run
        best = nil
        seeds.each do |seed|
          network = build(seed: seed)
          before = network.mean_squared_error(INPUTS, TARGETS)
          stats = network.train(INPUTS, TARGETS, epochs: 400)
          accuracy = Tasks.bipolar_accuracy(network, INPUTS, TARGETS)
          predictions = INPUTS.map { |input| network.forward(input, record: false).first }
          candidate = {
            seed: seed,
            before: before,
            mse: stats[:final_mse],
            accuracy: accuracy,
            predictions: predictions
          }
          best = candidate if best.nil? || candidate[:mse] < best[:mse]
          break if learned?(candidate)
        end

        Result.new(
          name: "XOR-вентиль (Layered)",
          success: learned?(best),
          summary: format(
            "точность %.0f%%, MSE %.4f → %.4f (seed %d)",
            best[:accuracy] * 100,
            best[:before],
            best[:mse],
            best[:seed]
          ),
          details: best
        )
      end

      def self.build(seed:)
        Topologies::Layered.new(
          input_size: 2,
          hidden_size: 6,
          output_size: 1,
          settle_steps: 4,
          learning_rate: 0.35,
          seed: seed,
          target_mse: 0.02,
          log: false
        )
      end

      def self.seeds
        [1, 2, 3, 4, 5]
      end

      def self.learned?(result)
        result[:accuracy] == 1.0 && result[:mse] < 0.05
      end
    end
  end
end
