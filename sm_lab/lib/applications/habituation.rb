# Habituation — один и тот же толчок перестаёт будить.
#
# Вес нулевой: ответ живёт в усталости. Пока толчки идут подряд,
# усталость тянет нейрон под порог. Пауза даёт ей утечь,
# и следующий такой же толчок снова слышен.

module SmLab
  class Habituation < Network
    POKE = 3.2
    TRAIN = 8
    GAP = 24
    AGAIN = 3

    def initialize(name: 'Habituation')
      super(
        name: name,
        neuron_count: 1,
        neuron_options: {
          bias: 1.6,
          slope: 2.5,
          threshold: 0.5,
          fatigue_gain: 0.18,
          fatigue_sensitivity: 1.0,
          fatigue_pull: 4.0
        },
        recover_rate: 0.08,
        homeostasis_rate: 0.0
      )
    end

    def build_topology
      @weights = [[0.0]]
    end

    def self.demo(plot: false)
      net = new
      schedule = Array.new(TRAIN, POKE) + Array.new(GAP, 0.0) + Array.new(AGAIN, POKE)
      acts = []
      fats = []
      schedule.each do |poke|
        net.step!(external_input: [poke], homeostasis: false)
        acts << net.neurons[0].activation
        fats << net.neurons[0].fatigue
      end

      train = acts.first(TRAIN)
      quiet = acts[TRAIN, GAP]
      again = acts.last(AGAIN)
      ok = train[0] > 0.9 && train[2] < train[0] && train[-1] < 0.25 &&
           quiet.max < 0.15 && again[0] > 0.9 && again[0] > again[1]

      plot_path = nil
      if plot
        plot_path = Plot.series_svg(
          { 'Активация' => acts, 'Усталость' => fats },
          File.expand_path('../../plots/examples/habituation.svg', __dir__),
          title: 'Привыкание: повтор гасит ответ',
          y_label: 'Уровень'
        )
      end

      text = <<~TEXT
        Привыкание, один нейрон
          толчок #{format('%.1f', POKE)}, серия из #{TRAIN}, пауза #{GAP}
          серия #{train.map { |value| format('%.2f', value) }.join(' → ')}
          тишина, максимум #{format('%.2f', quiet.max)}
          после паузы #{again.map { |value| format('%.2f', value) }.join(' → ')}
          активация #{Plot.sparkline(acts)}
          усталость #{Plot.sparkline(fats)}
          #{ok ? 'повтор перестал будить, пауза вернула ответ' : 'привыкание не сложилось'}
      TEXT
      {
        ok: ok, title: 'Привыкание', text: text, plot: plot_path,
        first: train[0], faded: train[-1], again: again[0]
      }
    end
  end
end
