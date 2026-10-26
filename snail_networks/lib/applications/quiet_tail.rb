# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Обход на решётке оставляет после импульса бегущий хвост.
    #
    # Пока ошибка кончается на такте эха, второй импульс встречает этот хвост
    # и выходит выше единицы. Четыре тихих кадра после эха входят в ту же
    # ошибку: хвост гаснет, и оба импульса приходят как 1.
    class QuietTail
      DELAY = 3
      TAIL = 4
      EPOCHS = 120
      RATE = 0.15

      def self.run
        short = train(0)
        quiet = train(TAIL)
        success = ringing?(short) && extinguished?(quiet)

        Result.new(
          name: "Гашение хвоста",
          success: success,
          summary: format(
            "без хвоста второй импульс %.2f, с хвостом %.2f",
            short[:pair][DELAY + 2],
            quiet[:pair][DELAY + 2]
          ),
          details: { short: short, quiet: quiet }
        )
      end

      def self.train(tail)
        network = DetourEcho.build(:grid)
        episodes = Tasks.shift_episodes(delay: DELAY, tail: tail)
        stats = network.train_sequence(episodes, epochs: EPOCHS, learning_rate: RATE)
        length = DELAY + 1 + TAIL
        {
          mse: stats[:final_mse],
          single: pulse(network, length, 1.0),
          pair: pulse_pair(network, 1.0),
          negative: pulse_pair(network, -1.0)
        }
      end

      def self.pulse(network, length, amplitude)
        frames = Array.new(length) { |time| [time.zero? ? amplitude : 0.0] }
        network.forward_sequence(frames).map(&:first)
      end

      def self.pulse_pair(network, amplitude)
        frames = Tasks.paired_frames(delay: DELAY, gap: 2, amplitude: amplitude)
        network.forward_sequence(frames).map(&:first)
      end

      def self.ringing?(row)
        echo = (row[:single][DELAY] - 1.0).abs < 0.05
        tail = row[:single][(DELAY + 1)..].any? { |value| value.abs > 0.2 }
        second = (row[:pair][DELAY + 2] - 1.0).abs > 0.2
        echo && tail && second
      end

      def self.extinguished?(row)
        row[:mse] < 0.02 && clean_shift?(row[:single], 1.0) &&
          matched_pair?(row[:pair], 1.0) && matched_pair?(row[:negative], -1.0)
      end

      def self.clean_shift?(trace, peak)
        trace.each_with_index.all? do |value, time|
          target = time == DELAY ? peak : 0.0
          (value - target).abs < 0.05
        end
      end

      def self.matched_pair?(trace, peak)
        expected = [0.0, 0.0, 0.0, peak, 0.0, peak]
        trace.zip(expected).all? { |value, target| (value - target).abs < 0.05 }
      end
    end
  end
end
