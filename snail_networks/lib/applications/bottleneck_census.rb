# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Пары, где маршрут длины 3 есть только с повтором вершины.
    #
    # Перепись маршрутов такие пары пропускала, если в том же графе был обход.
    # Здесь у звезды, вложенных колец, двойной спирали и клубка берётся
    # кратчайшая узкая пара и учится тем же бюджетом, что и простые пути.
    class BottleneckCensus
      DELAY = 3
      EPOCHS = 160
      RATE = 0.12
      SEED = 1
      NAMES = %w[star nested_rings double_helix chaotic_blob].freeze

      def self.run
        rows = table
        success = rows.size == NAMES.size && rows.map { |row| row[:name] } == NAMES &&
                  rows.all? { |row| row[:kind] == :bottleneck && row[:hops] == 1 && blocked?(row) }

        Result.new(
          name: "Узкие маршруты",
          success: success,
          summary: format(
            "звезда %.4f, кольца %.4f, спираль %.4f, клубок %.4f",
            *rows.map { |row| row[:mse] }
          ),
          details: { rows: rows, table: render(rows) }
        )
      end

      def self.table
        configs = NetworkBuilder.load_configs
        NAMES.map { |name| evaluate(name, configs) }
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
          kind: network.route_kind(ports[:input], ports[:output], DELAY),
          before: before,
          mse: stats[:final_mse],
          trace: network.forward_sequence(episodes[0][0]).map(&:first)
        }
      end

      def self.blocked?(row)
        row[:mse] > 0.05 && !on_time?(row[:trace])
      end

      def self.on_time?(trace)
        (trace[DELAY] - 1.0).abs < 0.05 && trace.first(DELAY).all? { |value| value.abs < 0.05 }
      end

      def self.choose_ports(network)
        best = nil
        network.neurons.size.times do |input|
          network.neurons.size.times do |output|
            next if input == output
            next unless network.route_kind(input, output, DELAY) == :bottleneck

            candidate = { input: input, output: output, hops: network.distance_between(input, output) }
            best = candidate if best.nil? || (rank(candidate) <=> rank(best)).negative?
          end
        end
        best
      end

      def self.rank(row)
        [row[:hops], row[:input], row[:output]]
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
        lines = [format("%-16s %6s %4s %10s %10s", "Топология", "Пара", "Хопы", "MSE до", "MSE после")]
        rows.each do |row|
          lines << format(
            "%-16s %6s %4d %10.4f %10.4f",
            row[:name], "#{row[:input]}→#{row[:output]}", row[:hops], row[:before], row[:mse]
          )
        end
        lines.join("\n")
      end
    end
  end
end
