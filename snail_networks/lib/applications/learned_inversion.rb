# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Лента Мёбиуса учится вернуть импульс с противоположным знаком.
    #
    # Выход — тот же нейрон, что принял кадр. Через длину ленты цель равна
    # минус вход. Переворот на замыкающем ребре делает эту цель достижимой:
    # обучение перебирает несколько зёрен и останавливается на точном решении.
    class LearnedInversion
      SIZE = 4

      def self.run
        episodes = Tasks.loop_episodes(steps: SIZE + 1, invert: true)
        best = nil

        seeds.each do |seed|
          network = build(seed)
          before = network.sequence_mse(episodes)
          stats = network.train_sequence(episodes, epochs: 80, learning_rate: 0.2)
          values = network.forward_sequence(episodes[0][0]).map(&:first)
          candidate = { seed: seed, before: before, mse: stats[:final_mse], trace: values }
          best = candidate if best.nil? || candidate[:mse] < best[:mse]
          break if solved?(candidate)
        end

        Result.new(
          name: "Обученная инверсия (MobiusStrip)",
          success: solved?(best),
          summary: format(
            "MSE %.4f → %.4f, возврат %s (seed %d)",
            best[:before],
            best[:mse],
            best[:trace].map { |value| format("% .2f", value) }.join(" →") ,
            best[:seed]
          ),
          details: best
        )
      end

      def self.build(seed)
        Topologies::MobiusStrip.new(
          size: SIZE,
          input_indices: [0],
          output_indices: [0],
          activation: :linear,
          settle_steps: SIZE,
          seed: seed,
          log: false
        )
      end

      def self.seeds
        [1, 3, 4, 5, 6]
      end

      def self.solved?(result)
        trace = result[:trace]
        result[:mse] < 0.02 && (trace[0] - 1.0).abs < 0.05 && (trace.last + 1.0).abs < 0.05 &&
          trace[1...-1].all? { |value| value.abs < 0.05 }
      end
    end
  end
end
