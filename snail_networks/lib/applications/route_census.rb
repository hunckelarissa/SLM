# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Все 12 топологий получают одну задержку на 3 такта и один бюджет.
    #
    # Пара нейронов выбирается так: сначала обход (простой путь длиннее
    # кратчайшего), затем узкое место (до цели добирается только маршрут
    # с повтором вершины), затем провод, затем пара без маршрута нужной длины.
    # Простой путь выучивается. Повтор вершины оставляет ранний приход.
    class RouteCensus
      DELAY = 3
      EPOCHS = 160
      RATE = 0.12
      SEED = 1
      RANK = { detour: 0, bottleneck: 1, wire: 2, none: 3 }.freeze
      LABELS = { detour: "обход", bottleneck: "узкое", wire: "провод", none: "нет хода" }.freeze

      def self.run
        rows = table
        learned = rows.select { |row| row[:kind] == :detour || row[:kind] == :wire }
        star = rows.find { |row| row[:name] == "star" }
        layered = rows.find { |row| row[:name] == "layered" }
        success = rows.size == 12 && rows.all? { |row| held?(row) } &&
                  learned.size >= 2 && star[:kind] == :bottleneck && layered[:kind] == :none

        Result.new(
          name: "Маршруты задержки",
          success: success,
          summary: format(
            "простой путь %d/%d с MSE < 0.02, звезда %.4f, слои %.4f",
            learned.count { |row| row[:mse] < 0.02 },
            learned.size,
            star[:mse],
            layered[:mse]
          ),
          details: { rows: rows, table: render(rows) }
        )
      end

      def self.table
        configs = NetworkBuilder.load_configs
        NetworkBuilder.names(configs).map { |name| evaluate(name, configs) }
      end

      def self.evaluate(name, configs)
        scout = NetworkBuilder.build(name, configs.merge(name => scout_params(configs[name])))
        ports = choose_ports(scout)
        network = training_network(name, configs, ports)
        episodes = Tasks.shift_episodes(delay: DELAY)
        before = network.sequence_mse(episodes)
        stats = network.train_sequence(episodes, epochs: EPOCHS, learning_rate: RATE)
        {
          name: name,
          input: ports[:input],
          output: ports[:output],
          hops: ports[:hops],
          kind: ports[:kind],
          pairs: ports[:pairs],
          before: before,
          mse: stats[:final_mse],
          trace: network.forward_sequence(episodes[0][0]).map(&:first)
        }
      end

      def self.held?(row)
        case row[:kind]
        when :detour, :wire
          row[:mse] < 0.02 && on_time?(row[:trace])
        when :bottleneck
          row[:mse] > 0.05 && row[:trace][row[:hops]].abs > 0.15
        when :none
          row[:mse] > 0.4
        else
          false
        end
      end

      def self.on_time?(trace)
        (trace[DELAY] - 1.0).abs < 0.05 && trace.first(DELAY).all? { |value| value.abs < 0.05 }
      end

      def self.choose_ports(network)
        best = nil
        counts = Hash.new(0)
        network.neurons.size.times do |input|
          network.neurons.size.times do |output|
            next if input == output

            kind = network.route_kind(input, output, DELAY)
            counts[kind] += 1
            candidate = {
              input: input,
              output: output,
              kind: kind,
              hops: network.distance_between(input, output)
            }
            best = candidate if best.nil? || (rank(candidate) <=> rank(best)).negative?
          end
        end
        best.merge(pairs: counts[best[:kind]])
      end

      def self.rank(row)
        [RANK.fetch(row[:kind]), row[:hops] || 99, row[:input], row[:output]]
      end

      def self.scout_params(params)
        params.merge("settle_steps" => 40, "log" => false, "seed" => SEED)
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

      def self.render(rows)
        lines = [format("%-16s %-8s %6s %4s %6s %10s %10s", "Топология", "Роль", "Пара", "Хопы", "Пар", "MSE до", "MSE после")]
        rows.each do |row|
          lines << format(
            "%-16s %-8s %6s %4d %6d %10.4f %10.4f",
            row[:name], LABELS.fetch(row[:kind]), "#{row[:input]}→#{row[:output]}",
            row[:hops], row[:pairs], row[:before], row[:mse]
          )
        end
        lines.join("\n")
      end
    end
  end
end
