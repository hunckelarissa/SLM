# FlatGarden — 2D сетка: четыре соседа возбуждают, диагонали тормозят.
#
# Это боковое торможение. Вспышка остаётся пятном: прямые соседи
# подхватывают её, диагонали проседают. Края замкнуты в тор.
# Число нейронов округляется до полного квадрата.

module SmLab
  class FlatGarden < Network
    NEIGHBOR_WEIGHT = 0.55
    DIAGONAL_WEIGHT = -0.4

    attr_reader :side

    def initialize(name: 'FlatGarden', neuron_count: 16, **options)
      side = Math.sqrt(neuron_count).round
      side = 1 if side < 1
      super(name: name, neuron_count: side * side, **options)
      @side = side
    end

    def build_topology
      n = size
      @weights = Array.new(n) { Array.new(n, 0.0) }

      @side.times do |row|
        @side.times do |col|
          index = row * @side + col
          add_link(index, ((row - 1 + @side) % @side) * @side + col)
          add_link(index, ((row + 1) % @side) * @side + col)
          add_link(index, row * @side + ((col - 1 + @side) % @side))
          add_link(index, row * @side + ((col + 1) % @side))
          add_diagonal(index, row, col, -1, -1)
          add_diagonal(index, row, col, -1, 1)
          add_diagonal(index, row, col, 1, -1)
          add_diagonal(index, row, col, 1, 1)
        end
      end
    end

    def layout
      @side.times.flat_map do |row|
        @side.times.map { |col| [col.to_f, row.to_f] }
      end
    end

    private

    def add_link(from, to)
      return if from == to

      @weights[from][to] = NEIGHBOR_WEIGHT
    end

    def add_diagonal(from, row, col, d_row, d_col)
      other_row = (row + d_row) % @side
      other_col = (col + d_col) % @side
      to = other_row * @side + other_col
      return if from == to
      return if @weights[from][to] == NEIGHBOR_WEIGHT

      @weights[from][to] = DIAGONAL_WEIGHT
    end
  end
end
