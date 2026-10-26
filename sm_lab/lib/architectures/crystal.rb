# Crystal — 3D решётка. Соседи по грани возбуждают, по ребру тормозят.
#
# Число нейронов округляется до полного куба. Грани замкнуты.

module SmLab
  class Crystal < Network
    NEIGHBOR_W = 0.5
    EDGE_W = -0.28

    attr_reader :side

    def initialize(name: 'Crystal', neuron_count: 27, **options)
      side = (neuron_count**(1.0 / 3.0)).round
      side = 1 if side < 1
      super(name: name, neuron_count: side * side * side, **options)
      @side = side
    end

    def build_topology
      n = size
      @weights = Array.new(n) { Array.new(n, 0.0) }
      span = @side

      n.times do |index|
        ix = index % span
        iy = (index / span) % span
        iz = index / (span * span)

        [-1, 0, 1].each do |dx|
          [-1, 0, 1].each do |dy|
            [-1, 0, 1].each do |dz|
              changed = [dx, dy, dz].count { |delta| delta != 0 }
              next if changed.zero? || changed > 2

              nx = (ix + dx) % span
              ny = (iy + dy) % span
              nz = (iz + dz) % span
              other = nz * span * span + ny * span + nx
              next if index == other

              @weights[index][other] = changed == 1 ? NEIGHBOR_W : EDGE_W
            end
          end
        end
      end
    end

    def layout
      span = @side
      size.times.map do |index|
        [index % span, (index / span) % span, index / (span * span)]
      end
    end
  end
end
