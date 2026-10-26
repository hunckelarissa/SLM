#!/usr/bin/env ruby
# runner.rb — Прогон архитектур SMLab.
#
#   ruby experiments/runner.rb
#   ruby experiments/runner.rb --all [steps] [neurons]
#   ruby experiments/runner.rb --single <name> [steps] [neurons]
#   ruby experiments/runner.rb --compare

require_relative '../lib/sm_lab'
require_relative '../lib/store'

module SmLab
  class Runner
    ARCHITECTURES = {
      'snail' => SnailHouse,
      'ring' => RingDance,
      'garden' => FlatGarden,
      'doll' => NestingDoll,
      'chaotic' => ChaoticBall,
      'crystal' => Crystal,
      'tentacles' => Tentacles,
      'helix' => DoubleHelix,
      'core' => PulsingCore,
      'labyrinth' => Labyrinth
    }.freeze

    DEFAULT_STEPS = 30
    DEFAULT_NEURONS = 10

    def initialize
      @store = Store.new
      @results = {}
    end

    def self.main
      runner = new
      if ARGV.empty?
        puts help_text
        runner.run_single(ARCHITECTURES['snail'], steps: DEFAULT_STEPS, neuron_count: DEFAULT_NEURONS)
      else
        case ARGV[0]
        when '--all'
          runner.run_all(steps: (ARGV[1] || DEFAULT_STEPS).to_i, neuron_count: (ARGV[2] || DEFAULT_NEURONS).to_i)
        when '--single'
          name = ARGV[1] || 'snail'
          steps = (ARGV[2] || DEFAULT_STEPS).to_i
          neurons = (ARGV[3] || DEFAULT_NEURONS).to_i
          arch = ARCHITECTURES[name] || raise("Неизвестная архитектура: #{name}. Доступны: #{ARCHITECTURES.keys.join(', ')}")
          runner.run_single(arch, steps: steps, neuron_count: neurons)
        when '--compare'
          runner.compare_architectures
        when '--help', '-h'
          puts help_text
        else
          puts "Неизвестный флаг: #{ARGV[0]}"
          puts help_text
        end
      end
    end

    def self.help_text
      <<~TEXT

        SMLab — экспериментатор
          --all [steps] [neurons]       все архитектуры
          --single <name> [steps] [neurons]
          --compare                     последние прогоны из data/smlab.db
          имена: #{ARCHITECTURES.keys.join(', ')}
      TEXT
    end

    def run_single(arch_class, steps: DEFAULT_STEPS, neuron_count: DEFAULT_NEURONS, input_type: :random)
      net = arch_class.new(neuron_count: neuron_count)
      puts "\n#{'=' * 70}"
      puts "  Эксперимент: #{net.name}"
      puts "  Запрошено нейронов: #{neuron_count}, в сети: #{net.size}, шагов: #{steps}, ввод: #{input_type}"
      puts "#{'=' * 70}"
      puts "\n[INIT] #{net.inspect}"

      Experiment.run(net, steps: steps, input_type: input_type)
      series = net.summary_series
      series.each do |point|
        next unless point[:step] == 1 || (point[:step] % 10).zero?

        puts format('  [%2d] act=%.4f fat=%.4f', point[:step], point[:avg_act], point[:avg_fat])
      end

      puts "\n[FINAL] #{net.inspect}"
      puts "  [info] #{net.info.inspect}"
      @store.record_run(name: net.name, neuron_count: net.size, input_type: input_type, frames: net.history)
      csv_path = save_csv(net, series)
      svg_path = Plot.series_svg(
        { 'Активация' => series.map { |point| point[:avg_act] }, 'Усталость' => series.map { |point| point[:avg_fat] } },
        File.join(plots_dir, "#{net.slug}_history.svg"),
        title: "#{net.name}: средние активация и усталость",
        y_label: 'Среднее'
      )
      puts "  [plot] #{csv_path}"
      puts "  [svg]  #{svg_path}"
      @results[net.name] = net.info
      net
    end

    def run_all(steps: DEFAULT_STEPS, neuron_count: DEFAULT_NEURONS)
      ARCHITECTURES.each_value { |arch| run_single(arch, steps: steps, neuron_count: neuron_count) }
      summarize
    end

    def compare_architectures
      if @store.empty?
        puts 'Нет сохранённых прогонов. Сначала: ruby generate_data.rb или ruby experiments/runner.rb --all'
        return
      end

      rows = @store.latest_summaries
      puts "\n#{'=' * 80}"
      puts '  СРАВНЕНИЕ АРХИТЕКТУР (последний прогон каждой)'
      puts "#{'=' * 80}"
      puts format('  %-18s %3s %-14s %7s %7s %7s %7s', 'Архитектура', 'N', 'Input', 'Act', 'Fat', 'Max', 'Min')
      puts "  #{'-' * 74}"
      rows.each do |row|
        _id, name, neurons, input, _steps, avg_act, avg_fat, max_act, min_act = row
        puts format('  %-18s %3d %-14s %7.4f %7.4f %7.4f %7.4f', name, neurons, input, avg_act, avg_fat, max_act, min_act)
      end
      puts "  #{'-' * 74}\n"
    end

    def summarize
      puts "\n#{'=' * 70}"
      puts "  СВОДКА: #{@results.size} конфигураций"
      puts "#{'=' * 70}"
      @results.each do |name, info|
        puts format('  %-18s | steps=%4d | act=%7.3f | fat=%7.3f',
                    name, info[:step_count], info[:avg_activation], info[:avg_fatigue])
      end
    end

    private

    def plots_dir
      File.expand_path('../plots', __dir__)
    end

    def save_csv(net, series)
      FileUtils.mkdir_p(plots_dir)
      path = File.join(plots_dir, "#{net.slug}_history.csv")
      lines = ['step,avg_activation,avg_fatigue']
      series.each { |point| lines << "#{point[:step]},#{point[:avg_act].round(6)},#{point[:avg_fat].round(6)}" }
      File.write(path, "#{lines.join("\n")}\n")
      path
    end
  end
end

SmLab::Runner.main if $PROGRAM_NAME == __FILE__
