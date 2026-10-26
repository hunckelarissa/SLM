# DelayLine — цепочка, по которой импульс идёт на один нейрон за шаг.
#
# Покой специально тихий, поэтому след виден. Это короткая память
# без обучения: где сейчас пик, там и «сейчас» относительно вспышки.

module SmLab
  class DelayLine < Network
    def initialize(name: 'DelayLine', neuron_count: 8, **options)
      raise ArgumentError, 'DelayLine needs at least 2 neurons' if neuron_count < 2

      super(
        name: name,
        neuron_count: neuron_count,
        neuron_options: {
          bias: 1.8,
          slope: 2.0,
          threshold: 0.5,
          fatigue_gain: 0.01,
          fatigue_sensitivity: 0.2,
          fatigue_pull: 0.0
        },
        recover_rate: 0.2,
        homeostasis_rate: 0.0,
        **options
      )
    end

    def build_topology
      @weights = Array.new(size) { Array.new(size, 0.0) }
      (size - 1).times { |index| @weights[index + 1][index] = 4.5 }
    end

    def self.demo(neuron_count: 8, plot: false)
      net = new(neuron_count: neuron_count)
      rows = []
      peaks = []
      neuron_count.times do |step|
        drive = Array.new(neuron_count, 0.0)
        drive[0] = 3.2 if step.zero?
        net.step!(external_input: drive, homeostasis: false)
        activations = net.neurons.map(&:activation)
        rows << activations
        peaks << activations.each_with_index.max_by { |value, _index| value }.last
      end
      hits = peaks.each_with_index.count { |peak, step| peak == step }
      ok = hits == neuron_count

      plot_path = nil
      if plot
        plot_path = Plot.heatmap_svg(
          rows,
          File.expand_path('../../plots/examples/echo.svg', __dir__),
          title: 'Эхо: импульс проходит по цепочке'
        )
      end

      chart = rows.each_with_index.map do |row, step|
        format('%d %s', step, row.map { |value| value > 0.5 ? '#' : '.' }.join)
      end.join("\n")

      text = <<~TEXT
        Эхо, линия задержки
          пик по шагам: #{peaks.join(' → ')}
          попаданий #{hits}/#{neuron_count}
        #{chart}
          #{ok ? 'импульс дошёл по порядку' : 'след рассыпался'}
      TEXT
      { ok: ok, title: 'Эхо', text: text, plot: plot_path, peaks: peaks }
    end
  end
end
