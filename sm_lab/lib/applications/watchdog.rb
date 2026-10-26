# Watchdog — сад, который молчит на ровном фоне и разносит выброс соседям.
#
# Сильный вход бьёт в одну клетку. На следующем шаге горят уже
# её соседи по решётке: тревога живёт в топологии, не в проводе датчика.

module SmLab
  class AlarmGarden < FlatGarden
    LINK = 2.5

    # Сторожу нужна чистая возбуждающая решётка. Диагональное торможение
    # сада сюда не входит: выброс должен дойти до четырёх соседей.
    def build_topology
      n = size
      @weights = Array.new(n) { Array.new(n, 0.0) }
      @side.times do |row|
        @side.times do |col|
          index = row * @side + col
          [[-1, 0], [1, 0], [0, -1], [0, 1]].each do |d_row, d_col|
            other = ((row + d_row) % @side) * @side + ((col + d_col) % @side)
            @weights[index][other] = LINK if other != index
          end
        end
      end
    end
  end

  class Watchdog
    THRESHOLD = 0.7

    def initialize(side: 4)
      @net = AlarmGarden.new(
        neuron_count: side * side,
        neuron_options: {
          bias: 2.0,
          slope: 3.0,
          threshold: 0.55,
          fatigue_gain: 0.01,
          fatigue_sensitivity: 0.15,
          fatigue_pull: 0.0
        },
        recover_rate: 0.15,
        homeostasis_rate: 0.0
      )
      @side = @net.side
      @rng = Random.new(11)
    end

    attr_reader :net, :side

    def self.demo(plot: false)
      guard = new
      baseline = 24.times.map { guard.observe(guard.background) }
      spike_index = 5
      spiked = guard.observe(guard.background(spike_index: spike_index, spike: 4.5))
      echo = guard.observe(guard.background)
      quiet = baseline.map { |sample| sample[:max] }.max
      neighbors = guard.neighbors_of(spike_index)
      spread = neighbors.include?(echo[:hotspot]) && echo[:max] > THRESHOLD
      direct = spiked[:hotspot] == spike_index && spiked[:max] > 0.9
      ok = quiet < 0.25 && direct && spread

      plot_path = nil
      if plot
        plot_path = Plot.heatmap_svg(
          echo[:grid].each_slice(guard.side).to_a,
          File.expand_path('../../plots/examples/anomaly.svg', __dir__),
          title: 'Сторож: на следующем шаге вспышка ушла к соседям',
          y_label: 'ряд'
        )
      end

      text = <<~TEXT.chomp
        Сторож аномалий, плоский сад #{guard.side}×#{guard.side}
          тихий фон, максимум активации #{quiet.round(3)}
          удар в клетку #{spike_index}: пик #{spiked[:max].round(3)}
          шаг спустя горячая клетка #{echo[:hotspot]} (соседи #{neighbors.join(', ')}), пик #{echo[:max].round(3)}
      TEXT
      text = "#{text}\n#{echo[:grid_text]}\n  " \
             "#{ok ? 'выброс разошёлся по решётке, ложной тревоги не было' : 'детектор промахнулся'}\n"
      { ok: ok, title: 'Сторож', text: text, plot: plot_path, quiet_max: quiet, hit: echo }
    end

    def background(spike_index: nil, spike: 0.0)
      drive = Array.new(@net.size) { 0.12 + @rng.rand(-0.03..0.03) }
      drive[spike_index] = spike if spike_index
      drive
    end

    def observe(drive)
      @net.step!(external_input: drive, homeostasis: false)
      activations = @net.neurons.map(&:activation)
      hotspot = activations.each_with_index.max_by { |value, _index| value }.last
      {
        max: activations.max,
        hotspot: hotspot,
        grid: activations,
        grid_text: grid_text(activations)
      }
    end

    def neighbors_of(index)
      row, col = index.divmod(@side)
      [[-1, 0], [1, 0], [0, -1], [0, 1]].map do |d_row, d_col|
        ((row + d_row) % @side) * @side + ((col + d_col) % @side)
      end
    end

    def grid_text(activations)
      glyphs = '·.:-=+*#%'
      activations.each_slice(@side).map do |row|
        row.map { |value| glyphs[(value * 8).clamp(0, 8).round] }.join
      end.join("\n")
    end
  end
end
