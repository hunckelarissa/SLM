# RingDance — кольцо, разрезанное на две противофазы.
#
# Нейрон возбуждает себя и тормозит противоположный.
# Сосед по ходу кольца получает слабый толчок, чтобы половины
# оставались одним танцем, а не россыпью пар.

module SmLab
  class RingDance < Network
    LATERAL = 0.35

    def initialize(name: 'RingDance', neuron_count: 10, **options)
      super(name: name, neuron_count: neuron_count, **Dynamics.tune(options))
    end

    def build_topology
      n = size
      @weights = Array.new(n) { Array.new(n, 0.0) }

      n.times do |index|
        @weights[index][index] = Dynamics::SELF_EXCITATION
        opposite = (index + n / 2) % n
        @weights[index][opposite] = Dynamics::RECIPROCAL_INHIBITION if opposite != index
        nxt = (index + 1) % n
        @weights[index][nxt] = LATERAL if nxt != index && nxt != opposite
      end
    end

    def halves
      n = size
      mid = n / 2
      [(0...mid).to_a, (mid...n).to_a]
    end

    def tonic_drive(level = Dynamics::TONIC)
      Dynamics.uniform_drive(size, level)
    end

    def rhythm_sides
      halves
    end

    def rhythm_labels
      ['Первая половина', 'Вторая половина']
    end

    def prepare_rhythm!
      high, low = halves
      Dynamics.kick(self, high: high, low: low)
      self
    end

    def layout
      n = size
      n.times.map do |index|
        angle = 2 * Math::PI * index / n
        [Math.cos(angle), Math.sin(angle)]
      end
    end
  end
end
