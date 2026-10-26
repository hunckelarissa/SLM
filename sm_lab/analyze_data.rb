#!/usr/bin/env ruby
# analyze_data.rb — Сравнение последних прогонов из data/smlab.db.

require_relative './lib/sm_lab'
require_relative './lib/store'

class DataAnalyzer
  RHYTHM_NETS = {
    'RingDance' => SmLab::RingDance,
    'DoubleHelix' => SmLab::DoubleHelix,
    'PulsingCore' => SmLab::PulsingCore,
    'NestingDoll' => SmLab::NestingDoll
  }.freeze

  def initialize
    @store = SmLab::Store.new
  end

  def run
    if @store.empty?
      puts 'База пуста. Сначала: ruby generate_data.rb'
      return
    end

    rows = @store.latest_summaries
    puts "\n#{'=' * 80}"
    puts '  АНАЛИЗ ДАННЫХ SMLAB'
    puts "#{'=' * 80}\n"
    puts '  СРАВНЕНИЕ АРХИТЕКТУР'
    puts "  #{'-' * 74}"
    puts format('  %-18s %3s %-14s %7s %7s %7s %7s', 'Архитектура', 'N', 'Input', 'Act', 'Fat', 'Max', 'Min')
    puts "  #{'-' * 74}"
    rows.each do |row|
      _id, name, neurons, input, _steps, avg_act, avg_fat, max_act, min_act = row
      puts format('  %-18s %3d %-14s %7.4f %7.4f %7.4f %7.4f', name, neurons, input, avg_act, avg_fat, max_act, min_act)
    end

    activations = rows.map { |row| row[5] }
    puts "\n  Средняя финальная активность: #{activations.sum.fdiv(activations.size).round(4)}"
    hottest = rows.max_by { |row| row[5] }
    quietest = rows.min_by { |row| row[5] }
    puts "  Выше всех: #{hottest[1]} (#{hottest[5].round(4)})"
    puts "  Ниже всех: #{quietest[1]} (#{quietest[5].round(4)})"

    rows.each { |row| report_rhythm(row) if row[3] == 'rhythm' }

    snail = rows.find { |row| row[1] == 'SnailHouse' }
    return unless snail

    series = @store.series(snail[0])
    if snail[3] == 'crawl'
      peaks = series.map do |step, _act, _fat|
        @store.activations(snail[0], step).each_with_index.max_by { |value, _index| value }.last
      end
      puts "\n  SnailHouse: горб идёт #{peaks.join('→')}"
      puts '  Средняя активация почти ровная: горит одна клетка, остальные молчат.'
    end
    puts "\n  SnailHouse по шагам (спарклайн растянут от минимума серии к максимуму)"
    puts format('  активация, финал %.3f', series.last[1])
    puts "  #{SmLab::Plot.sparkline(series.map { |_step, act, _fat| act })}"
    puts format('  усталость, финал %.3f', series.last[2])
    puts "  #{SmLab::Plot.sparkline(series.map { |_step, _act, fat| fat })}"

    values = @store.activations_for(snail[0])
    puts "\n  Гистограмма активаций SnailHouse, все #{series.size} шагов"
    histogram(values).each do |label, count, bar|
      puts format('  %-15s %s (%d)', label, bar, count)
    end
    puts "\n  АНАЛИЗ ЗАВЕРШЁН.\n"
  end

  private

  def report_rhythm(row)
    run_id, name, neurons, = row
    net = RHYTHM_NETS.fetch(name).new(neuron_count: neurons)
    frames = @store.series(run_id).map { |step, _act, _fat| @store.activations(run_id, step) }
    left_indexes, right_indexes = net.rhythm_sides
    left = SmLab::Dynamics.mean_series(frames, left_indexes).drop(15)
    right = SmLab::Dynamics.mean_series(frames, right_indexes).drop(15)
    fraction = SmLab::Dynamics.opposed_fraction(left, right)
    flips = SmLab::Dynamics.flips(left, right)
    left_label, right_label = net.rhythm_labels
    puts format("\n  %s: %.0f%% шагов врозь, переключений %d", name, fraction * 100, flips)
    puts "  #{left_label} #{SmLab::Plot.sparkline(left)}"
    puts "  #{right_label} #{SmLab::Plot.sparkline(right)}"
  end

  def histogram(values, bins: 6)
    return [] if values.empty?

    min, max = values.minmax
    if (max - min) < 1e-9
      return [[format('%.3f', min), values.size, '#' * [values.size, 40].min]]
    end

    width = (max - min) / bins
    counts = Array.new(bins, 0)
    values.each do |value|
      index = ((value - min) / width).floor
      index = bins - 1 if index >= bins
      counts[index] += 1
    end
    peak = [counts.max, 1].max
    counts.each_with_index.map do |count, index|
      lo = min + index * width
      hi = lo + width
      [format('%.3f–%.3f', lo, hi), count, '#' * (count * 40 / peak)]
    end
  end
end

DataAnalyzer.new.run if $PROGRAM_NAME == __FILE__
