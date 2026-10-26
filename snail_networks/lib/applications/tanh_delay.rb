# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Та же задержка на три такта, но с tanh вместо линейной активации.
    #
    # Цель на выходе 0.5, а не 1: каскад tanh не достаёт до асимптоты,
    # и градиент там ещё живой. Ноль до срока задержки сохраняется.
    class TanhDelay
      DELAY = 3
      PEAK = 0.5

      def self.run
        episodes = Tasks.shift_episodes(delay: DELAY, peak: PEAK)
        network = build
        before = network.sequence_mse(episodes)
        stats = network.train_sequence(episodes, epochs: 60, learning_rate: 0.3)
        positive = network.forward_sequence(episodes[0][0]).map(&:first)
        negative = network.forward_sequence(episodes[1][0]).map(&:first)
        on_time = (positive[DELAY] - PEAK).abs < 0.05 && (negative[DELAY] + PEAK).abs < 0.05
        quiet = positive[0...DELAY].all? { |value| value.abs < 0.05 } &&
                negative[0...DELAY].all? { |value| value.abs < 0.05 }

        Result.new(
          name: "Задержка на tanh (Ring)",
          success: stats[:final_mse] < 0.02 && on_time && quiet,
          summary: format(
            "MSE %.4f → %.4f, импульс %s",
            before,
            stats[:final_mse],
            positive.map { |value| format("% .2f", value) }.join(" →")
          ),
          details: { before: before, after: stats[:final_mse], positive: positive, negative: negative }
        )
      end

      def self.build
        Topologies::Ring.new(
          size: 6,
          input_indices: [0],
          output_indices: [DELAY],
          activation: :tanh,
          settle_steps: DELAY,
          seed: 1,
          log: false
        )
      end
    end
  end
end
