# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Два датчика говорят только с центром, центр рассылает решение на два актуатора.
    #
    # Аналитические веса уже реализуют консенсус: оба выхода равны и растут,
    # когда растёт сумма входов. Затем та же таблица ответов учится с нуля
    # эволюционным поиском — узкое горлышко звезды для этой задачи достаточно.
    class StarConsensus
      INPUTS = [[0.0, 0.0], [1.0, 0.0], [0.0, 1.0], [1.0, 1.0]].freeze

      def self.run
        analytical = build_analytical
        responses = INPUTS.map { |input| analytical.forward(input, record: false) }
        low, left, _right, high = responses
        broadcast = responses.all? { |pair| (pair[0] - pair[1]).abs < 1e-9 }
        ordered = low.all? { |value| value.abs < 1e-9 } && left.all? { |value| value > 0.3 } && high.all? { |value| value > left.max }
        targets = responses
        student = build_student
        before = student.mean_squared_error(INPUTS, targets)
        stats = student.train(INPUTS, targets, epochs: 60)
        learned = stats[:final_mse] < before

        Result.new(
          name: "Консенсус датчиков (Star)",
          success: broadcast && ordered && learned,
          summary: format(
            "хаб: 0 → %.3f → %.3f; обучение MSE %.4f → %.4f",
            left[0],
            high[0],
            before,
            stats[:final_mse]
          ),
          details: { responses: responses, before: before, after: stats[:final_mse] }
        )
      end

      def self.build_analytical
        network = Topologies::Star.new(settle_steps: 4, seed: 1, log: false)
        network.clear_parameters!
        network.set_synapse(1, 0, 1.0)
        network.set_synapse(2, 0, 1.0)
        network.set_synapse(0, 7, 1.5)
        network.set_synapse(0, 8, 1.5)
        network
      end

      def self.build_student
        Topologies::Star.new(
          settle_steps: 4,
          seed: 11,
          population_size: 24,
          mutation_rate: 0.45,
          mutation_scale: 0.35,
          log: false
        )
      end
    end
  end
end
