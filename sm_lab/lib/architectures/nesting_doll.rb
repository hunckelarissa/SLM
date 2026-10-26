# NestingDoll — внутреннее кольцо вспыхивает, наружное его осаживает.
#
# Внутри кольца связь возбуждающая. Радиально снаружи внутрь
# идёт торможение, изнутри наружу — возбуждение. Матрёшка дышит.

module SmLab
  class NestingDoll < Network
    def initialize(name: 'NestingDoll', neuron_count: 10, **options)
      super(name: name, neuron_count: neuron_count, **Dynamics.tune(options))
    end

    def build_topology
      n = size
      @weights = Array.new(n) { Array.new(n, 0.0) }
      groups = rings

      groups.each do |ring|
        next if ring.size < 2

        link = Dynamics::SELF_EXCITATION / ring.size
        ring.each do |index|
          ring.each { |other| @weights[index][other] = link if index != other }
        end
      end

      groups.each_cons(2) do |inner, outer|
        inward = Dynamics::RECIPROCAL_INHIBITION / outer.size
        outward = Dynamics::SELF_EXCITATION / inner.size
        inner.each do |inner_index|
          outer.each do |outer_index|
            @weights[inner_index][outer_index] = inward
            @weights[outer_index][inner_index] = outward
          end
        end
      end
    end

    def rings
      partition_rings(size)
    end

    def tonic_drive(level = Dynamics::TONIC)
      inner = rings.first
      Array.new(size, 0.0).tap { |drive| inner.each { |index| drive[index] = level } }
    end

    def rhythm_sides
      [rings.first, rings.last]
    end

    def rhythm_labels
      ['Внутреннее кольцо', 'Наружное кольцо']
    end

    def layout
      points = Array.new(size)
      rings.each_with_index do |ring, ring_index|
        radius = 0.45 + ring_index * 0.7
        ring.each_with_index do |index, cursor|
          angle = 2 * Math::PI * cursor / ring.size
          points[index] = [radius * Math.cos(angle), radius * Math.sin(angle)]
        end
      end
      points
    end

    private

    def partition_rings(n)
      num_rings = [[Math.sqrt(n).to_i, 4].min, 2].max
      num_rings = [num_rings, n].min
      ring_size = n / num_rings
      remainder = n - ring_size * num_rings
      start = 0
      num_rings.times.map do |ring_index|
        length = ring_size + (ring_index < remainder ? 1 : 0)
        ring = (start...(start + length)).to_a
        start += length
        ring
      end
    end
  end
end
