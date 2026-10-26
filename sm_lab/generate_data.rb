#!/usr/bin/env ruby
# generate_data.rb — Свежий журнал и CSV/SVG по всем десяти топологиям.
# Повторный запуск заменяет строки в data/smlab.db.

require_relative './lib/sm_lab'
require_relative './lib/store'

class DataGenerator
  CONFIGS = [
    { arch: SmLab::SnailHouse, neurons: 10, steps: 40, input: :crawl },
    { arch: SmLab::RingDance, neurons: 8, steps: 80, input: :rhythm },
    { arch: SmLab::FlatGarden, neurons: 9, steps: 50, input: :center_pulse },
    { arch: SmLab::NestingDoll, neurons: 12, steps: 80, input: :rhythm },
    { arch: SmLab::ChaoticBall, neurons: 10, steps: 50, input: :random },
    { arch: SmLab::Crystal, neurons: 27, steps: 50, input: :random },
    { arch: SmLab::Tentacles, neurons: 12, steps: 40, input: :crawl },
    { arch: SmLab::DoubleHelix, neurons: 10, steps: 80, input: :rhythm },
    { arch: SmLab::PulsingCore, neurons: 16, steps: 80, input: :rhythm },
    { arch: SmLab::Labyrinth, neurons: 10, steps: 40, input: :crawl }
  ].freeze

  def initialize
    @root = __dir__
    @plots = File.join(@root, 'plots')
    @store = SmLab::Store.new
  end

  def run
    FileUtils.mkdir_p(@plots)
    @store.clear!
    CONFIGS.each { |config| generate_one(config) }
    puts "\n#{'=' * 60}"
    puts '  ВСЕ ДАННЫЕ СОХРАНЕНЫ'
    puts "  SQLite: #{@store.path}"
    puts "  Рисунки: #{@plots}"
    puts "#{'=' * 60}"
  end

  private

  def generate_one(config)
    net = config[:arch].new(neuron_count: config[:neurons])
    puts "\n[#{net.name}] запрошено=#{config[:neurons]} в сети=#{net.size} steps=#{config[:steps]} input=#{config[:input]}"
    SmLab::Experiment.run(net, steps: config[:steps], input_type: config[:input])
    @store.record_run(name: net.name, neuron_count: net.size, input_type: config[:input], frames: net.history)
    series = net.summary_series
    write_steps_csv(net)
    write_history_csv(net, series)
    SmLab::Plot.series_svg(
      { 'Активация' => series.map { |point| point[:avg_act] }, 'Усталость' => series.map { |point| point[:avg_fat] } },
      File.join(@plots, "#{net.slug}_history.svg"),
      title: "#{net.name}: средние активация и усталость",
      y_label: 'Среднее'
    )
    if config[:input] == :crawl
      rows = net.history.map { |frame| frame[:state].map { |neuron| neuron[:activation] } }
      SmLab::Plot.heatmap_svg(
        rows,
        File.join(@plots, "#{net.slug}_crawl.svg"),
        title: "#{net.name}: горб ползёт по клеткам",
        y_label: 'шаг'
      )
      peaks = rows.map { |row| row.each_with_index.max_by { |value, _index| value }.last }
      puts "  ход #{peaks.join('→')}"
    elsif config[:input] == :rhythm
      frames = net.history.map { |frame| frame[:state].map { |neuron| neuron[:activation] } }
      left_indexes, right_indexes = net.rhythm_sides
      left = SmLab::Dynamics.mean_series(frames, left_indexes)
      right = SmLab::Dynamics.mean_series(frames, right_indexes)
      left_label, right_label = net.rhythm_labels
      SmLab::Plot.series_svg(
        { left_label => left, right_label => right },
        File.join(@plots, "#{net.slug}_rhythm.svg"),
        title: "#{net.name}: группы в противофазе",
        y_label: 'Средняя активация'
      )
      fraction = SmLab::Dynamics.opposed_fraction(left.drop(15), right.drop(15))
      flips = SmLab::Dynamics.flips(left.drop(15), right.drop(15))
      puts format('  противофаза %.0f%%, переключений %d', fraction * 100, flips)
    end
    puts format('  [OK] avg_act=%.4f avg_fat=%.4f', net.mean_activation, net.mean_fatigue)
  end

  def write_steps_csv(net)
    path = File.join(@plots, "#{net.slug}_steps.csv")
    lines = ['step,neuron_id,activation,fatigue,state']
    net.history.each do |frame|
      frame[:state].each do |neuron|
        lines << [frame[:step], neuron[:id], neuron[:activation], neuron[:fatigue], neuron[:state]].join(',')
      end
    end
    File.write(path, "#{lines.join("\n")}\n")
  end

  def write_history_csv(net, series)
    path = File.join(@plots, "#{net.slug}_history.csv")
    lines = ['step,avg_activation,avg_fatigue']
    series.each { |point| lines << "#{point[:step]},#{point[:avg_act].round(6)},#{point[:avg_fat].round(6)}" }
    File.write(path, "#{lines.join("\n")}\n")
  end
end

DataGenerator.new.run if $PROGRAM_NAME == __FILE__
