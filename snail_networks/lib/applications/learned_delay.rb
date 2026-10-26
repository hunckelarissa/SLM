# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Кольцо само находит веса линии задержки.
    #
    # Раньше единичные веса подставлялись вручную. Здесь обратное распространение
    # сквозь такты учит сдвиг импульса на три нейрона: и +1, и −1, и тишину.
    class LearnedDelay
      DELAY = 3

      def self.run
        episodes = Tasks.shift_episodes(delay: DELAY)
        network = build
        before = network.sequence_mse(episodes)
        stats = network.train_sequence(episodes, epochs: 40, learning_rate: 0.25)
        positive = trace(network, episodes[0])
        negative = trace(network, episodes[1])
        on_time = (positive[DELAY] - 1.0).abs < 0.05 && (negative[DELAY] + 1.0).abs < 0.05
        quiet = positive[0...DELAY].all? { |value| value.abs < 0.05 } &&
                negative[0...DELAY].all? { |value| value.abs < 0.05 }

        Result.new(
          name: "Обученная задержка (Ring)",
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
          activation: :linear,
          settle_steps: DELAY,
          seed: 1,
          log: false
        )
      end

      def self.trace(network, episode)
        network.forward_sequence(episode[0]).map(&:first)
      end
    end
  end
end
