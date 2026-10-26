# SnailHouse — по виткам ползёт один горб.
#
# Следующая камера слушает предыдущую сильно. Предыдущая и дальний
# виток получают торможение, поэтому хвост гаснет и горб не перепрыгивает.
# Один импульс в первую камеру, дальше сеть молчит и горб идёт сам.

module SmLab
  class SnailHouse < Network
    SPACING = 0.3
    JUMP = -0.8

    def initialize(name: 'SnailHouse', neuron_count: 10, **options)
      super(name: name, neuron_count: neuron_count, **Dynamics.wave(options))
    end

    def build_topology
      n = size
      @weights = Array.new(n) { Array.new(n, 0.0) }
      return if n < 2

      n.times do |index|
        @weights[(index + 1) % n][index] = Dynamics::CRAWL_FORWARD
        behind = (index - 1 + n) % n
        @weights[behind][index] = Dynamics::CRAWL_BACK if behind != (index + 1) % n
        distant = (index + 3) % n
        next if [index, (index + 1) % n, behind].include?(distant)

        @weights[distant][index] = JUMP
      end
    end

    def crawl_order
      (0...size).to_a
    end

    def pulse_index
      0
    end

    def drive_at(step)
      Dynamics.pulse_drive(size, pulse_index, step)
    end

    def layout
      size.times.map do |index|
        angle = index * SPACING
        radius = index * SPACING * 0.1 + 0.1
        [radius * Math.cos(angle), radius * Math.sin(angle)]
      end
    end
  end
end
