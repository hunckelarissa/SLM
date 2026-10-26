# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Все 12 топологий учат одно и то же эхо: импульс через 3 такта.
    #
    # Бюджет общий. Вход и выход выбираются так, чтобы кратчайший путь был
    # равен 3, если такой есть. Если диаметр меньше, сети приходится помнить,
    # а не просто протащить сигнал. У слоёв и звезды путь короче задержки.
    class EchoCensus
      DELAY = 3
      EPOCHS = 50
      RATE = 0.1
      SEED = 1

      def self.run
        rows = table
        ring = rows.find { |row| row[:name] == "ring" }
        layered = rows.find { |row| row[:name] == "layered" }
        star = rows.find { |row| row[:name] == "star" }
        paths = rows.select { |row| row[:kind] == "путь" }
        memories = rows.select { |row| row[:kind] == "память" }
        success = rows.size == 12 &&
                  paths.all? { |row| row[:hops] == DELAY && row[:mse] < 0.05 } &&
                  memories.size >= 2 &&
                  memories.all? { |row| row[:hops] < DELAY && row[:mse] > ring[:mse] }

        Result.new(
          name: "Эхо на 12 топологиях",
          success: success,
          summary: format(
            "кольцо %.4f (путь %d), слои %.4f, звезда %.4f",
            ring[:mse], ring[:hops], layered[:mse], star[:mse]
          ),
          details: { rows: rows, table: render(rows) }
        )
      end

      def self.table
        configs = NetworkBuilder.load_configs
        NetworkBuilder.names(configs).map { |name| evaluate(name, configs) }
      end

      def self.evaluate(name, configs)
        ports = choose_ports(scout(name, configs), DELAY)
        network = training_network(name, configs, ports)
        episodes = Tasks.shift_episodes(delay: DELAY)
        before = network.sequence_mse(episodes)
        stats = network.train_sequence(episodes, epochs: EPOCHS, learning_rate: RATE)
        trace = network.forward_sequence(episodes[0][0]).map(&:first)
        {
          name: name,
          type: configs[name]["type"],
          input: ports[:input],
          output: ports[:output],
          hops: ports[:hops],
          kind: kind(ports[:hops]),
          before: before,
          mse: stats[:final_mse],
          trace: trace
        }
      end

      def self.scout(name, configs)
        params = configs[name].merge("settle_steps" => 40, "log" => false, "seed" => SEED)
        NetworkBuilder.build(name, configs.merge(name => params))
      end

      def self.training_network(name, configs, ports)
        params = configs[name].merge(
          "settle_steps" => [ports[:hops], 1].max,
          "log" => false,
          "seed" => SEED,
          "activation" => "linear",
          "input_indices" => [ports[:input]],
          "output_indices" => [ports[:output]]
        )
        params.delete("input_size")
        params.delete("output_size")
        NetworkBuilder.build(name, configs.merge(name => params))
      end

      # Точное расстояние delay лучше короткого: тогда эхо — это провод, а не память.
      # Если такого пути нет, берётся самый длинный из более коротких.
      def self.choose_ports(network, delay)
        best = nil
        network.neurons.each do |source|
          distances_from(network, source.index).each do |target, hops|
            next if target == source.index || hops.zero?

            candidate = { input: source.index, output: target, hops: hops }
            best = candidate if better?(candidate, best, delay)
          end
        end
        best
      end

      def self.better?(candidate, current, delay)
        return true if current.nil?

        (rank(candidate, delay) <=> rank(current, delay)).negative?
      end

      def self.rank(row, delay)
        band = if row[:hops] == delay
                 0
               elsif row[:hops] < delay
                 1
               else
                 2
               end
        distance_penalty = row[:hops] == delay ? 0 : (row[:hops] - delay).abs
        [band, distance_penalty, row[:input], row[:output]]
      end

      def self.distances_from(network, source)
        distances = { source => 0 }
        queue = [source]
        until queue.empty?
          current = queue.shift
          network.synapses.each do |synapse|
            next unless synapse.source.index == current

            nxt = synapse.target.index
            next if distances.key?(nxt)

            distances[nxt] = distances[current] + 1
            queue << nxt
          end
        end
        distances
      end

      def self.kind(hops)
        if hops == DELAY
          "путь"
        elsif hops < DELAY
          "память"
        else
          "позже"
        end
      end

      def self.render(rows)
        lines = [format("%-16s %4s %6s %10s %10s", "Топология", "Хопы", "Роль", "MSE до", "MSE после")]
        rows.each do |row|
          lines << format("%-16s %4d %6s %10.4f %10.4f", row[:name], row[:hops], row[:kind], row[:before], row[:mse])
        end
        lines.join("\n")
      end
    end
  end
end
