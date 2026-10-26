# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Обычное кольцо возвращает импульс в тот же нейрон с тем же знаком.
    #
    # Прямой штраф на промежуточных тактах забивает градиент с конца петли:
    # вход и выход — один нейрон. Маска оставляет ошибку только на приёме
    # импульса и на его возврате, а сквозь середину градиент проходит свободно.
    class LearnedReturn
      SIZE = 4
      MASK = [1.0, 0.0, 0.0, 0.0, 1.0].freeze

      def self.run
        episodes = Tasks.loop_episodes(steps: SIZE + 1, invert: false)
        network = build
        before = network.sequence_mse(episodes, mask: MASK)
        stats = network.train_sequence(episodes, epochs: 160, learning_rate: 0.2, mask: MASK)
        trace = network.forward_sequence(episodes[0][0]).map(&:first)
        returned = (trace[0] - 1.0).abs < 0.05 && (trace.last - 1.0).abs < 0.05
        quiet = trace[1...-1].all? { |value| value.abs < 0.05 }

        Result.new(
          name: "Возврат в кольцо (Ring)",
          success: stats[:final_mse] < 0.02 && returned && quiet,
          summary: format(
            "MSE %.4f → %.4f, след %s",
            before,
            stats[:final_mse],
            trace.map { |value| format("% .2f", value) }.join(" →")
          ),
          details: { before: before, after: stats[:final_mse], trace: trace }
        )
      end

      def self.build
        Topologies::Ring.new(
          size: SIZE,
          input_indices: [0],
          output_indices: [0],
          activation: :linear,
          settle_steps: SIZE,
          seed: 1,
          log: false
        )
      end
    end
  end
end
