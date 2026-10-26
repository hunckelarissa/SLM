# Antagonism — два разных ритма архитектур.
#
# Кольцо, спираль ДНК, ядро и матрёшка мигают двумя группами.
# Улитка, лабиринт и щупальца несут один горб по кругу.

module SmLab
  class Antagonism
    def self.demo(plot: false)
      crawls = [
        crawl_story('Улитка', SnailHouse.new(neuron_count: 10)),
        crawl_story('Лабиринт', Labyrinth.new(neuron_count: 10)),
        crawl_story('Щупальца', Tentacles.new(neuron_count: 12))
      ]
      rhythms = [
        population('Кольцо', RingDance.new(neuron_count: 8)) { |net| net.halves },
        population('Спираль ДНК', DoubleHelix.new(neuron_count: 10)) { |net| net.strands },
        population('Ядро', PulsingCore.new(neuron_count: 16)) { |net| net.populations },
        breathe('Матрёшка', NestingDoll.new(neuron_count: 12))
      ]
      contrast = garden_contrast
      ok = crawls.all? { |story| story[:ok] } && rhythms.all? { |story| story[:ok] } && contrast[:ok]

      plot_path = nil
      if plot
        plot_path = Plot.heatmap_svg(
          crawls.first[:frames],
          File.expand_path('../../plots/examples/crawl.svg', __dir__),
          title: 'Улитка: горб проходит виток за витком',
          y_label: 'шаг'
        )
        ring = rhythms.first
        Plot.series_svg(
          { 'Первая половина' => ring[:left], 'Вторая половина' => ring[:right] },
          File.expand_path('../../plots/examples/antagonism.svg', __dir__),
          title: 'Кольцо: половины в противофазе',
          y_label: 'Средняя активация'
        )
      end

      lines = ['Ход горба']
      crawls.each { |story| lines << crawl_line(story) }
      lines << 'Противофаза'
      rhythms.each { |story| lines << story_line(story) }
      lines << format('  сад: сосед %.3f против диагонали %.3f', contrast[:face], contrast[:diagonal])
      lines << (ok ? '  горб проходит круг, противофаза держится у остальных' : '  ход или противофаза распались')
      text = "#{lines.join("\n")}\n"
      { ok: ok, title: 'Торможение', text: text, plot: plot_path, rhythms: rhythms, crawls: crawls, contrast: contrast }
    end

    def self.population(name, network)
      high, low = yield network
      Dynamics.kick(network, high: high, low: low)
      frames = Dynamics.trace(network, steps: 80, drive: network.tonic_drive)
      score(name, frames, high, low)
    end

    def self.breathe(name, network)
      inner = network.rings.first
      outer = network.rings.last
      frames = Dynamics.trace(network, steps: 80, drive: network.tonic_drive)
      score(name, frames, inner, outer)
    end

    def self.score(name, frames, high, low)
      left = Dynamics.mean_series(frames, high)
      right = Dynamics.mean_series(frames, low)
      window_left = left.drop(15)
      window_right = right.drop(15)
      fraction = Dynamics.opposed_fraction(window_left, window_right)
      flips = Dynamics.flips(window_left, window_right)
      {
        name: name,
        ok: fraction > 0.75 && flips >= 3,
        fraction: fraction,
        flips: flips,
        left: left,
        right: right
      }
    end

    def self.crawl_story(name, network, steps: 30)
      order = network.crawl_order
      frames = Dynamics.crawl(network, steps: steps)
      peaks = frames.map { |row| order.max_by { |index| row[index] } }
      fraction = Dynamics.advance_fraction(peaks, order)
      margin = frames.sum { |row| ordered = row.sort; ordered[-1] - ordered[-2] } / frames.size
      {
        name: name,
        ok: fraction >= 0.9 && margin > 0.5,
        fraction: fraction,
        margin: margin,
        peaks: peaks,
        frames: frames
      }
    end

    def self.crawl_line(story)
      hits = (story[:fraction] * (story[:peaks].size - 1)).round
      format("  %-12s %d/%d шагов вперёд, запас %.2f\n    %s",
             story[:name], hits, story[:peaks].size - 1, story[:margin], story[:peaks].join('→'))
    end

    def self.garden_contrast
      garden = FlatGarden.new(neuron_count: 9)
      garden.neurons.each { |neuron| neuron.activation = 0.05 }
      garden.neurons[4].activation = 1.0
      garden.step!(external_input: Array.new(garden.size, 0.0), homeostasis: false)
      face = garden.neurons[1].activation
      diagonal = garden.neurons[0].activation
      { ok: face > diagonal + 0.05, face: face, diagonal: diagonal }
    end

    def self.story_line(story)
      format("  %-12s %3d%% шагов врозь, переключений %d\n    A %s\n    B %s",
             story[:name], (story[:fraction] * 100).round, story[:flips],
             Plot.sparkline(story[:left]), Plot.sparkline(story[:right]))
    end
    private_class_method :population, :breathe, :score, :garden_contrast, :story_line, :crawl_story, :crawl_line
  end
end
