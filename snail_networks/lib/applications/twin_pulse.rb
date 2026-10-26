# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Второй импульс пускается, пока первый ещё в пути.
    #
    # Кольцо, выученное как линия задержки, проводит оба: линейное как 1 и 1,
    # tanh как 0.5 и 0.5. Решётка, выученная обходом, первый импульс отдаёт
    # точно, а второй уже встречает хвост волны и приходит выше единицы.
    class TwinPulse
      DELAY = 3
      GAP = 2

      def self.run
        linear = ride(:linear)
        tanh = ride(:tanh)
        grid = ride(:grid)
        success = shift?(linear, 1.0) && shift?(tanh, 0.5) && piled?(grid)

        Result.new(
          name: "Два импульса",
          success: success,
          summary: format(
            "кольцо %s; tanh %s; решётка %s",
            pretty(linear), pretty(tanh), pretty(grid)
          ),
          details: { linear: linear, tanh: tanh, grid: grid }
        )
      end

      def self.ride(kind)
        network = build(kind)
        frames = Tasks.paired_frames(delay: DELAY, gap: GAP)
        network.forward_sequence(frames).map(&:first)
      end

      def self.build(kind)
        case kind
        when :linear
          network = LearnedDelay.build
          network.train_sequence(Tasks.shift_episodes(delay: DELAY), epochs: 40, learning_rate: 0.25)
          network
        when :tanh
          network = TanhDelay.build
          network.train_sequence(Tasks.shift_episodes(delay: DELAY, peak: TanhDelay::PEAK), epochs: 60, learning_rate: 0.3)
          network
        when :grid
          network = DetourEcho.build(:grid)
          network.train_sequence(Tasks.shift_episodes(delay: DELAY), epochs: DetourEcho::EPOCHS, learning_rate: DetourEcho::RATE)
          network
        else
          raise ArgumentError, "Неизвестный участник #{kind}"
        end
      end

      def self.shift?(trace, peak)
        expected = [0.0, 0.0, 0.0, peak, 0.0, peak]
        trace.zip(expected).all? { |value, target| (value - target).abs < 0.05 }
      end

      def self.piled?(trace)
        (trace[DELAY] - 1.0).abs < 0.05 && trace[DELAY + 1].abs < 0.05 && (trace[DELAY + GAP] - 1.0).abs > 0.2
      end

      def self.pretty(trace)
        trace.map { |value| format("% .2f", value) }.join("→")
      end
    end
  end
end
