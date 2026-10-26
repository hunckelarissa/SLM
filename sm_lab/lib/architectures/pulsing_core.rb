# PulsingCore — ядро и периферия дышат в противофазе.
#
# Внутри каждой группы возбуждение. Между группами торможение:
# когда ядро занято, периферия молчит, и наоборот.

module SmLab
  class PulsingCore < Network
    attr_reader :core_size

    def initialize(name: 'PulsingCore', neuron_count: 16, **options)
      super(name: name, neuron_count: neuron_count, **Dynamics.tune(options))
      @core_size = if neuron_count == 1
                     1
                   else
                     [[(neuron_count * 0.3).to_i, 1].max, neuron_count / 2].min
                   end
    end

    def build_topology
      @weights = Array.new(size) { Array.new(size, 0.0) }
      Dynamics.couple_populations(@weights, core_indexes, periphery_indexes)
    end

    def core_indexes
      (0...@core_size).to_a
    end

    def periphery_indexes
      (@core_size...size).to_a
    end

    def populations
      [core_indexes, periphery_indexes]
    end

    def tonic_drive(level = Dynamics::TONIC)
      Dynamics.uniform_drive(size, level)
    end

    def rhythm_sides
      populations
    end

    def rhythm_labels
      ['Ядро', 'Периферия']
    end

    def prepare_rhythm!
      high, low = populations
      Dynamics.kick(self, high: high, low: low)
      self
    end

    def layout
      points = Array.new(size)
      @core_size.times do |index|
        angle = 2 * Math::PI * index / [@core_size, 1].max
        points[index] = [0.4 * Math.cos(angle), 0.4 * Math.sin(angle)]
      end
      outer = size - @core_size
      outer.times do |index|
        angle = 2 * Math::PI * index / outer
        points[@core_size + index] = [1.2 * Math.cos(angle), 1.2 * Math.sin(angle)]
      end
      points
    end
  end
end
