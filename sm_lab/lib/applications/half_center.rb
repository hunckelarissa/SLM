# HalfCenter — центральный генератор ритма.
#
# Два нейрона взаимно тормозятся и устают. Тонический вход
# держит их в цикле: кто активен, тот копирует усталость и
# отпускает соседа. Так устроены спинальные генераторы шага.

module SmLab
  class HalfCenter < Network
    TONIC = 3.5

    def initialize(name: 'HalfCenter', neuron_count: 2)
      raise ArgumentError, 'HalfCenter uses exactly 2 neurons' unless neuron_count == 2

      super(
        name: name,
        neuron_count: 2,
        neuron_options: {
          bias: 0.5,
          threshold: 0.5,
          slope: 2.5,
          fatigue_gain: 0.12,
          fatigue_sensitivity: 0.4,
          fatigue_pull: 3.0
        },
        recover_rate: 0.1,
        homeostasis_rate: 0.0
      )
    end

    def build_topology
      @weights = [
        [2.5, -4.0],
        [-4.0, 2.5]
      ]
    end

    # Ломает симметрию, иначе оба нейрона идут в ногу.
    def kick!
      self.neurons[0].activation = 0.2
      self.neurons[1].activation = 0.9
      self.neurons[0].fatigue = 0.05
      self.neurons[1].fatigue = 0.0
      self
    end

    def self.demo(steps: 90, plot: false)
      net = new
      net.kick!
      left = []
      right = []
      steps.times do
        net.step!(external_input: [TONIC, TONIC], homeostasis: false)
        left << net.neurons[0].activation
        right << net.neurons[1].activation
      end

      window_left = left.drop(20)
      window_right = right.drop(20)
      opposed = window_left.zip(window_right).count { |l_act, r_act| (l_act - r_act).abs > 0.35 }
      fraction = opposed.fdiv(window_left.size)
      signs = window_left.zip(window_right).map { |l_act, r_act| l_act > r_act }
      flips = signs.each_cons(2).count { |before, after| before != after }
      ok = fraction > 0.75 && flips >= 4

      plot_path = nil
      if plot
        plot_path = Plot.series_svg(
          { 'Левая' => left, 'Правая' => right },
          File.expand_path('../../plots/examples/gait.svg', __dir__),
          title: 'Походка: полуцентры левой и правой сторон',
          y_label: 'Активация'
        )
      end

      text = <<~TEXT
        Походка, генератор ритма из двух нейронов
          противофаза: #{(fraction * 100).round}% шагов после разогрева, переключений: #{flips}
          L #{Plot.sparkline(left)}
          R #{Plot.sparkline(right)}
          #{ok ? 'ритм устойчивый' : 'ритм не сложился'}
      TEXT
      { ok: ok, title: 'Походка', text: text, plot: plot_path, fraction: fraction, flips: flips }
    end
  end
end
