# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Импульс должен прийти через 3 такта, хотя соседи связаны напрямую.
    #
    # У решётки есть обход вокруг клетки, не использующий прямое ребро.
    # Обучение глушит это ребро и проводит сигнал длинным маршрутом.
    # У звезды любой маршрут длины 3 из центра в луч заканчивается тем же
    # ребром, что и путь длины 1: заглушить ранний приход значит заглушить и поздний.
    class DetourEcho
      DELAY = 3
      EPOCHS = 80
      RATE = 0.15
      SEED = 1

      def self.run
        episodes = Tasks.shift_episodes(delay: DELAY)
        grid = train(:grid, episodes)
        star = train(:star, episodes)
        success = grid[:learned] && star[:blocked] &&
                  grid[:hops] == 1 && star[:hops] == 1 &&
                  grid[:walk] && star[:walk]

        Result.new(
          name: "Обход короткого пути",
          success: success,
          summary: format(
            "решётка MSE %.4f, прямое ребро %.3f; звезда MSE %.4f, след на такте 1 %.2f",
            grid[:mse], grid[:direct], star[:mse], star[:trace][1]
          ),
          details: { grid: grid, star: star }
        )
      end

      def self.train(kind, episodes)
        network = build(kind)
        before = network.sequence_mse(episodes)
        stats = network.train_sequence(episodes, epochs: EPOCHS, learning_rate: RATE)
        positive = network.forward_sequence(episodes[0][0]).map(&:first)
        negative = network.forward_sequence(episodes[1][0]).map(&:first)
        input = network.input_indices.first
        output = network.output_indices.first
        {
          before: before,
          mse: stats[:final_mse],
          trace: positive,
          negative: negative,
          direct: direct_weight(network),
          hops: network.hop_distance(output),
          walk: network.reachable_in?(input, output, DELAY),
          learned: learned?(positive, negative, direct_weight(network), stats[:final_mse]),
          blocked: stats[:final_mse] > 0.1 && positive[1].abs > 0.2
        }
      end

      def self.learned?(positive, negative, direct, mse)
        mse < 0.02 && direct.abs < 0.05 &&
          (positive[DELAY] - 1.0).abs < 0.05 && (negative[DELAY] + 1.0).abs < 0.05 &&
          positive[0...DELAY].all? { |value| value.abs < 0.05 } &&
          negative[0...DELAY].all? { |value| value.abs < 0.05 }
      end

      def self.direct_weight(network)
        input = network.input_indices.first
        output = network.output_indices.first
        synapse = network.synapses.find do |item|
          item.source.index == input && item.target.index == output
        end
        synapse.weight
      end

      def self.build(kind)
        common = { activation: :linear, seed: SEED, log: false, input_indices: [0], output_indices: [1] }
        case kind
        when :grid
          Topologies::FlatSquare.new(common.merge(settle_steps: 4))
        when :star
          Topologies::Star.new(common.merge(settle_steps: 3))
        else
          raise ArgumentError, "Неизвестный участник #{kind}"
        end
      end
    end
  end
end
