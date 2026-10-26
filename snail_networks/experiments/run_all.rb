# frozen_string_literal: true

# Сравнение 12 топологий на одной таблице: XOR, AND, чётность и OR.
# Входы и цели — −1 и +1: ноль не толкает tanh. Обучение — обратный проход
# сквозь удержанный вход, один шаг 0.2 для всех графов.
#
# Число эпох можно урезать, не правя YAML:
#   SNAIL_EPOCHS=20 ruby experiments/run_all.rb

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "snail_networks"
require "benchmark"
require "csv"
require "fileutils"

def run_all
  configs = SnailNetwork::NetworkBuilder.load_configs
  results = []

  puts "=" * 78
  puts "SNAIL NETWORKS — 12 топологий, XOR / AND / чётность / OR"
  puts "=" * 78

  configs.each do |name, params|
    puts "\n--- #{name} (#{params['type']}) ---"
    network = SnailNetwork::NetworkBuilder.build(name, configs)
    epochs = ENV.fetch("SNAIL_EPOCHS", params["epochs"] || 300).to_i
    inputs, targets = SnailNetwork::Tasks.parity_bipolar(
      params["input_size"], params["output_size"], level: :sign
    )
    distances = network.output_indices.map { |index| network.hop_distance(index) }

    puts "  Нейронов: #{network.neurons.size}, синапсов: #{network.synapses.size}, seed: #{network.rng.seed}"
    puts "  Хопы до выходов: #{distances.join(', ')}"

    before = network.mean_squared_error(inputs, targets)
    stats = nil
    elapsed = Benchmark.realtime do
      stats = network.train_settled(inputs, targets, epochs: epochs, learning_rate: 0.2)
    end
    accuracy = SnailNetwork::Tasks.bipolar_accuracy(network, inputs, targets)

    puts "  Точность знака: #{format('%.1f', accuracy * 100)}%"
    puts "  MSE:            #{format('%.4f', before)} → #{format('%.4f', stats[:final_mse])}"
    puts "  Время:          #{format('%.2f', elapsed)} с (эпох #{stats[:history].size})"

    network.forward(inputs.first, record: true)
    network.save_activity(File.join("logs", "#{name}_activity.csv"))
    network.plot_activity(File.join("logs", "#{name}_activity.svg"), title: name)
    unless stats[:history].empty?
      SnailNetwork::Chart.line(
        [{ name: "MSE", values: stats[:history] }],
        File.join("logs", "#{name}_mse.svg"),
        title: "#{name}: MSE"
      )
    end
    network.save_weights(File.join("data", "#{name}_weights.json"))
    network.visualize(File.join("data", "#{name}.svg"))

    results << {
      name: name,
      type: params["type"],
      seed: network.rng.seed,
      accuracy: accuracy,
      mse_before: before,
      mse_after: stats[:final_mse],
      time: elapsed
    }
  end

  FileUtils.mkdir_p("data")
  CSV.open(File.join("data", "summary.csv"), "w") do |csv|
    csv << %w[name type seed accuracy mse_before mse_after seconds]
    results.each do |row|
      csv << [row[:name], row[:type], row[:seed], row[:accuracy], row[:mse_before], row[:mse_after], row[:time]]
    end
  end

  SnailNetwork::Chart.bars(
    results.sort_by { |row| -row[:accuracy] }.map { |row| { label: row[:name], value: row[:accuracy] } },
    File.join("data", "summary.svg"),
    title: "Точность знака"
  )

  puts "\n" + ("=" * 78)
  puts "СВОДКА"
  puts "=" * 78
  puts format("%-16s %-14s %10s %12s %12s %8s", "Топология", "Тип", "Точность", "MSE до", "MSE после", "сек")
  puts "-" * 78
  results.sort_by { |row| -row[:accuracy] }.each do |row|
    puts format(
      "%-16s %-14s %9.1f%% %12.4f %12.4f %8.2f",
      row[:name], row[:type], row[:accuracy] * 100, row[:mse_before], row[:mse_after], row[:time]
    )
  end
  puts "=" * 78
  puts "Ряды активаций и графики SVG — в logs/, веса, summary.csv и summary.svg — в data/."
end

run_all if $PROGRAM_NAME == __FILE__
