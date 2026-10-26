# DoubleHelix — две цепи. Вдоль цепи возбуждение, поперёк торможение.
#
# Прямой мостик — взаимное подавление. Цепи дышат в противофазе,
# как две половины генератора шага, растянутые в спираль.

module SmLab
  class DoubleHelix < Network
    FORWARD = 1.35
    BACK = 1.15

    def initialize(name: 'DoubleHelix', neuron_count: 10, **options)
      super(name: name, neuron_count: neuron_count, **Dynamics.tune(options))
      @chains = if neuron_count.even?
                  [neuron_count / 2, neuron_count / 2]
                else
                  [neuron_count / 2, neuron_count / 2 + 1]
                end
    end

    def build_topology
      n = size
      @weights = Array.new(n) { Array.new(n, 0.0) }
      first_size, second_size = @chains
      first = (0...first_size).to_a
      second = (first_size...n).to_a

      wire_chain(first)
      wire_chain(second)

      [first_size, second_size].min.times do |index|
        @weights[first[index]][second[index]] = Dynamics::RECIPROCAL_INHIBITION
        @weights[second[index]][first[index]] = Dynamics::RECIPROCAL_INHIBITION
      end
    end

    def strands
      first_size, = @chains
      [(0...first_size).to_a, (first_size...size).to_a]
    end

    def tonic_drive(level = Dynamics::TONIC)
      Dynamics.uniform_drive(size, level)
    end

    def rhythm_sides
      strands
    end

    def rhythm_labels
      ['Первая цепь', 'Вторая цепь']
    end

    def prepare_rhythm!
      high, low = strands
      Dynamics.kick(self, high: high, low: low)
      self
    end

    def layout
      first_size, = @chains
      size.times.map do |index|
        strand = index < first_size ? 0 : 1
        along = strand.zero? ? index : index - first_size
        length = strand.zero? ? first_size : size - first_size
        angle = 2 * Math::PI * along / [length, 1].max
        [0.8 * Math.cos(angle) + strand * 0.35, along * 0.45, 0.8 * Math.sin(angle)]
      end
    end

    private

    def wire_chain(chain)
      return if chain.size < 2

      chain.each_with_index do |index, cursor|
        @weights[index][chain[(cursor + 1) % chain.size]] = FORWARD
        @weights[index][chain[(cursor - 1 + chain.size) % chain.size]] = BACK
      end
    end
  end
end
