# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Таблица XOR / AND / чётность / OR на входах −1 и +1.
    #
    # Ноль не толкает tanh, поэтому сравнение идёт на знаковых уровнях
    # и общим обратным проходом сквозь удержанный вход. Куб и вложенные
    # кольца разделяют все знаки. Кольцо из YAML — нет.
    class SignTable
      EPOCHS = 200
      RATE = 0.2

      def self.run
        rows = table
        cube = rows.find { |row| row[:name] == "cube" }
        nested = rows.find { |row| row[:name] == "nested_rings" }
        ring = rows.find { |row| row[:name] == "ring" }
        star = rows.find { |row| row[:name] == "star" }
        success = rows.size == 12 && solved?(cube) && solved?(nested) &&
                  ring[:accuracy] < 0.75 && star[:accuracy] > ring[:accuracy]

        Result.new(
          name: "Знаковая таблица",
          success: success,
          summary: format(
            "куб %.4f, вложенные кольца %.4f, кольцо %.0f%%",
            cube[:mse], nested[:mse], ring[:accuracy] * 100
          ),
          details: { rows: rows, table: render(rows) }
        )
      end

      def self.table
        configs = NetworkBuilder.load_configs
        NetworkBuilder.names(configs).map { |name| evaluate(name, configs) }
      end

      def self.evaluate(name, configs)
        params = configs[name].merge("log" => false)
        network = NetworkBuilder.build(name, configs.merge(name => params))
        inputs, targets = Tasks.parity_bipolar(
          network.input_indices.size, network.output_indices.size, level: :sign
        )
        before = network.mean_squared_error(inputs, targets)
        stats = network.train_settled(inputs, targets, epochs: EPOCHS, learning_rate: RATE)
        {
          name: name,
          before: before,
          mse: stats[:final_mse],
          accuracy: Tasks.bipolar_accuracy(network, inputs, targets)
        }
      end

      def self.solved?(row)
        row[:accuracy] == 1.0 && row[:mse] < 0.05
      end

      def self.render(rows)
        lines = [format("%-16s %8s %10s %10s", "Топология", "Точность", "MSE до", "MSE после")]
        rows.each do |row|
          lines << format(
            "%-16s %7.0f%% %10.4f %10.4f",
            row[:name], row[:accuracy] * 100, row[:before], row[:mse]
          )
        end
        lines.join("\n")
      end
    end
  end
end
