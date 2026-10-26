# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Одинаковое эхо через 3 такта, одинаковый бюджет обучения.
    #
    # У кольца выход стоит ровно на третьем ребре, и сдвиг находится сразу.
    # У звезды кратчайший путь равен двум рёбрам через центр: тот же импульс
    # перемешивается, и ошибка остаётся большой.
    class EchoRace
      DELAY = 3
      EPOCHS = 40
      RATE = 0.25

      def self.run
        episodes = Tasks.shift_episodes(delay: DELAY)
        ring = train(:ring, episodes)
        star = train(:star, episodes)
        success = ring[:mse] < 0.05 && star[:mse] > 0.4 && ring[:mse] < star[:mse]

        Result.new(
          name: "Эхо: кольцо против звезды",
          success: success,
          summary: format("кольцо MSE %.4f, звезда MSE %.4f", ring[:mse], star[:mse]),
          details: { ring: ring, star: star }
        )
      end

      def self.train(kind, episodes)
        network = build(kind)
        before = network.sequence_mse(episodes)
        stats = network.train_sequence(episodes, epochs: EPOCHS, learning_rate: RATE)
        { before: before, mse: stats[:final_mse] }
      end

      def self.build(kind)
        common = { activation: :linear, seed: 3, log: false }
        case kind
        when :ring
          Topologies::Ring.new(
            common.merge(size: 6, input_indices: [0], output_indices: [DELAY], settle_steps: DELAY)
          )
        when :star
          Topologies::Star.new(common.merge(input_indices: [1], output_indices: [7], settle_steps: 4))
        else
          raise ArgumentError, "Неизвестный участник #{kind}"
        end
      end
    end
  end
end
