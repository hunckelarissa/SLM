# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Длина тихого хвоста и шаг обучения связаны.
    #
    # Четыре кадра после эха при шаге 0.15 гасятся. Шесть кадров при том же
    # шаге разгоняют линейную решётку. Тот же хвост из шести кадров при шаге
    # 0.05 снова сходится, и второй импульс приходит как 1.
    class TailStep
      DELAY = 3

      def self.run
        short = train(tail: 4, rate: 0.15, epochs: 120)
        steep = train(tail: 6, rate: 0.15, epochs: 120)
        gentle = train(tail: 6, rate: 0.05, epochs: 180)
        success = clean?(short) && steep[:mse] > 10 && clean?(gentle)

        Result.new(
          name: "Шаг и длина хвоста",
          success: success,
          summary: format(
            "4 кадра при 0.15 → %.4f; 6 кадров при 0.15 → %.1f; 6 кадров при 0.05 → %.4f",
            short[:mse], steep[:mse], gentle[:mse]
          ),
          details: { short: short, steep: steep, gentle: gentle }
        )
      end

      def self.train(tail:, rate:, epochs:)
        network = DetourEcho.build(:grid)
        episodes = Tasks.shift_episodes(delay: DELAY, tail: tail)
        stats = network.train_sequence(episodes, epochs: epochs, learning_rate: rate)
        frames = Tasks.paired_frames(delay: DELAY, gap: 2)
        {
          mse: stats[:final_mse],
          pair: network.forward_sequence(frames).map(&:first)
        }
      end

      def self.clean?(row)
        expected = [0.0, 0.0, 0.0, 1.0, 0.0, 1.0]
        row[:mse] < 0.02 && row[:pair].zip(expected).all? { |value, target| (value - target).abs < 0.05 }
      end
    end
  end
end
