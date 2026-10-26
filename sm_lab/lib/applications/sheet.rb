# Sheet — горб идёт по листу и сворачивает к другому соседу.
#
# Впереди клетка слушает горб сильно, сзади и по бокам он её гасит.
# Поворот не зажигает новую вспышку: те же связи смотрят уже
# на северного соседа, и горб шагает туда.

module SmLab
  class Sheet < FlatGarden
    LATERAL = -1.2

    attr_reader :heading

    def initialize(name: 'Sheet', side: 4, heading: [0, 1])
      raise ArgumentError, 'Sheet needs a side of at least 3' if side < 3

      @heading = heading
      super(name: name, neuron_count: side * side, **Dynamics.wave)
    end

    def turn!(heading)
      @heading = heading
      build_topology
      self
    end

    def build_topology
      n = @side
      d_row, d_col = @heading
      @weights = Array.new(size) { Array.new(size, 0.0) }
      n.times do |row|
        n.times do |col|
          source = row * n + col
          ahead = ((row + d_row) % n) * n + ((col + d_col) % n)
          behind = ((row - d_row) % n) * n + ((col - d_col) % n)
          @weights[ahead][source] = Dynamics::CRAWL_FORWARD
          @weights[behind][source] = Dynamics::CRAWL_BACK if behind != ahead
          [[-d_col, d_row], [d_col, -d_row]].each do |l_row, l_col|
            lateral = ((row + l_row) % n) * n + ((col + l_col) % n)
            next if [source, ahead, behind].include?(lateral)

            @weights[lateral][source] = LATERAL
          end
        end
      end
    end

    def self.demo(steps: 8, plot: false)
      net = new
      peaks = []
      margins = []
      turns = 0
      steps.times do |step|
        if step == net.side
          net.turn!([-1, 0])
          turns += 1
        end
        net.step!(external_input: Dynamics.pulse_drive(net.size, 0, step), homeostasis: false)
        row = net.neurons.map(&:activation)
        hot = row.each_with_index.max_by { |value, _index| value }.last
        peaks << hot.divmod(net.side)
        margins << (row.max - row.sort[-2])
      end

      ok = turns == 1 && margins.min > 0.9 && peaks == [
        [0, 0], [0, 1], [0, 2], [0, 3],
        [3, 3], [2, 3], [1, 3], [0, 3]
      ]

      plot_path = nil
      if plot
        frames = net.history.map { |frame| frame[:state].map { |neuron| neuron[:activation] } }
        plot_path = Plot.heatmap_svg(
          frames,
          File.expand_path('../../plots/examples/sheet.svg', __dir__),
          title: 'Лист: горб поворачивает за угол',
          y_label: 'шаг'
        )
      end

      east = peaks.first(net.side).map { |point| point.join(',') }
      north = peaks.drop(net.side).map { |point| point.join(',') }
      marks = Array.new(net.side) { Array.new(net.side, '·') }
      peaks.each { |row, col| marks[row][col] = '#' }
      lines = [
        'Лист, горб по клеткам тора',
        "  восток #{east.join(' → ')}",
        "  север #{north.join(' → ')}",
        "  запас #{format('%.2f', margins.min)}",
        marks.map(&:join).join("\n"),
        (ok ? 'горб прошёл ряд и свернул по столбцу' : 'ход рассыпался')
      ]
      {
        ok: ok, title: 'Лист', text: "#{lines.join("\n")}\n", plot: plot_path,
        peaks: peaks, turns: turns
      }
    end
  end
end
