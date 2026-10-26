# Worm — две волны в одном теле.
#
# Прямое кольцо несёт горб к голове, обратное — к хвосту.
# Веса не переписываются. Касание стены — это внешний толчок:
# оно гасит прямое кольцо и зажигает обратное в том же сегменте,
# после чего горб ползёт назад и тело отступает.

module SmLab
  class Worm < Network
    SEGMENTS = 8
    WALL = 1.0
    QUENCH = -6.0
    CONFIDENT = 0.5

    attr_reader :segments

    def initialize(name: 'Worm', segments: SEGMENTS, **options)
      raise ArgumentError, 'Worm needs at least 3 segments' if segments < 3

      @segments = segments
      super(name: name, neuron_count: segments * 2, **Dynamics.wave(options))
    end

    def build_topology
      n = @segments
      @weights = Array.new(size) { Array.new(size, 0.0) }
      n.times do |index|
        @weights[(index + 1) % n][index] = Dynamics::CRAWL_FORWARD
        @weights[(index - 1) % n][index] = Dynamics::CRAWL_BACK
        back = n + index
        @weights[n + ((index - 1) % n)][back] = Dynamics::CRAWL_FORWARD
        @weights[n + ((index + 1) % n)][back] = Dynamics::CRAWL_BACK
      end
    end

    def quench_drive(ring)
      drive = Array.new(size, 0.0)
      offset = ring == :backward ? @segments : 0
      @segments.times { |index| drive[offset + index] = QUENCH }
      drive
    end

    def seed_drive(ring, segment)
      drive = Array.new(size, 0.0)
      index = segment % @segments
      index += @segments if ring == :backward
      drive[index] = Dynamics::PULSE
      drive
    end

    def focus
      row = neurons.map(&:activation)
      hot_index = row.each_with_index.max_by { |value, _index| value }.last
      {
        segment: hot_index % @segments,
        ring: hot_index < @segments ? :forward : :backward,
        margin: row.max - row.sort[-2]
      }
    end

    def self.signed_step(before, after, count)
      return 1 if after == (before + 1) % count
      return -1 if after == (before - 1) % count

      0
    end

    def self.demo(steps: 24, plot: false)
      net = new
      net.build_topology
      weights_before = net.weights.map(&:dup)
      wall = WALL
      stride = 1.0 / net.segments
      position = 0.0
      positions = [position]
      trace = []
      phase = :out
      anchor = 0
      turns = 0
      confident = nil

      steps.times do |step|
        if phase == :out && confident && confident[:ring] == :forward && (position + stride) >= wall
          phase = :quench
          anchor = confident[:segment]
          turns += 1
        end
        drive = case phase
                when :quench then net.quench_drive(:forward)
                when :seed then net.seed_drive(:backward, anchor)
                else Dynamics.pulse_drive(net.size, 0, step)
                end
        net.step!(external_input: drive, homeostasis: false)
        seen = net.focus
        if confident && seen[:margin] > CONFIDENT && confident[:margin] > CONFIDENT
          position += signed_step(confident[:segment], seen[:segment], net.segments) * stride
          positions << position
        end
        trace << seen if seen[:margin] > CONFIDENT
        confident = seen if seen[:margin] > CONFIDENT
        phase = if phase == :quench
                  :seed
                elsif phase == :seed
                  :back
                else
                  phase
                end
      end

      farthest = positions.max
      finish = positions.last
      forward = trace.take_while { |item| item[:ring] == :forward }.map { |item| item[:segment] }
      backward = trace.drop(forward.size).map { |item| item[:segment] }
      moves = trace.each_cons(2).map { |before, after| signed_step(before[:segment], after[:segment], net.segments) }
      weights_same = net.weights == weights_before
      ok = turns == 1 && weights_same && farthest < wall && finish.negative? &&
           moves.count(1) >= 6 && moves.count(-1) >= 6

      plot_path = nil
      if plot
        plot_path = Plot.series_svg(
          { 'Положение' => positions },
          File.expand_path('../../plots/examples/worm.svg', __dir__),
          title: 'Червь: касание гасит прямой ход',
          y_label: 'Положение'
        )
      end

      text = <<~TEXT
        Червь, две волны в одном теле
          стена #{format('%.2f', wall)}, дальше всех #{format('%.2f', farthest)}, финиш #{format('%.2f', finish)}
          разворотов #{turns}, веса #{weights_same ? 'на месте' : 'переписаны'}
          вперёд #{forward.join('→')}
          назад #{backward.join('→')}
          положение #{Plot.sparkline(positions)}
          #{ok ? 'касание погасило прямой ход, червь отполз' : 'ход развалился'}
      TEXT
      {
        ok: ok, title: 'Червь', text: text, plot: plot_path, turns: turns,
        farthest: farthest, finish: finish, wall: wall, weights_same: weights_same
      }
    end
  end
end
