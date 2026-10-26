# RhythmReader — линия задержки как память, линейный считыватель как решение.
#
# Организм не учится. Он только раскладывает ритм по нейронам.
# Короткая регрессия снаружи отличает три рисунка импульсов.

module SmLab
  class RhythmReader
    PATTERNS = {
      0 => [1, 1, 1, 0, 0, 0],
      1 => [1, 0, 1, 0, 1, 0],
      2 => [1, 1, 0, 0, 1, 1]
    }.freeze

    def self.demo(plot: false, seed: 5)
      reader = new(seed: seed)
      train = reader.collect(per_class: 12, noise: 0.15)
      weights = reader.fit(train)
      test = reader.collect(per_class: 12, noise: 0.15)
      accuracy = reader.accuracy(weights, test)
      ok = accuracy >= 0.9

      plot_path = nil
      if plot
        preview = new(seed: 1)
        rows = preview.playback(PATTERNS[1], noise: 0.0)
        plot_path = Plot.heatmap_svg(
          rows,
          File.expand_path('../../plots/examples/rhythm.svg', __dir__),
          title: 'Ритм 101010, разложенный по линии задержки'
        )
      end

      text = <<~TEXT
        Чтение ритма
          три рисунка по 6 тактов, сеть из #{PATTERNS[0].size} нейронов не обучается
          учится только линейный считыватель (#{train.size} примеров)
          точность на новых примерах с шумом: #{(accuracy * 100).round}%
          #{ok ? 'рисунки различимы по следу в сети' : 'считыватель не отделил ритмы'}
      TEXT
      { ok: ok, title: 'Ритм', text: text, plot: plot_path, accuracy: accuracy }
    end

    def initialize(seed:)
      @rng = Random.new(seed)
    end

    def collect(per_class:, noise:)
      PATTERNS.flat_map do |label, pattern|
        per_class.times.map { { label: label, state: embed(pattern, noise: noise) } }
      end
    end

    def embed(pattern, noise:)
      net = DelayLine.new(neuron_count: pattern.size)
      pattern.each do |bit|
        drive = Array.new(pattern.size, 0.0)
        drive[0] = bit * 3.2 + @rng.rand(-noise..noise)
        net.step!(external_input: drive, homeostasis: false)
      end
      net.neurons.map(&:activation)
    end

    def playback(pattern, noise:)
      net = DelayLine.new(neuron_count: pattern.size)
      pattern.map do |bit|
        drive = Array.new(pattern.size, 0.0)
        drive[0] = bit * 3.2 + @rng.rand(-noise..noise)
        net.step!(external_input: drive, homeostasis: false)
        net.neurons.map(&:activation)
      end
    end

    # Один против остальных: три считывателя, побеждает больший отклик.
    def fit(samples)
      (0..2).map do |label|
        labels = samples.map { |sample| sample[:label] == label ? 1.0 : 0.0 }
        Readout.fit(samples.map { |sample| sample[:state] }, labels, lambda: 0.08)
      end
    end

    def accuracy(weights, samples)
      hits = samples.count do |sample|
        scores = weights.map { |row| Readout.predict(row, sample[:state]) }
        scores.each_with_index.max_by { |score, _index| score }.last == sample[:label]
      end
      hits.fdiv(samples.size)
    end
  end
end
