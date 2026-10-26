# SimpleMatrix — лёгкая матрица на чистом Ruby.
# Её использует шаг сети: веса × прошлые активации.

module SmLab
  class SimpleMatrix
    attr_reader :rows, :cols, :data

    def initialize(rows, cols, fill = 0.0)
      @rows = rows
      @cols = cols
      @data = Array.new(rows) { Array.new(cols, fill.to_f) }
    end

    def self.zeros(rows, cols = nil)
      cols ||= rows
      new(rows, cols, 0.0)
    end

    def self.rows(data)
      raise ArgumentError, 'matrix rows are empty' if data.nil? || data.empty?

      cols = data.first.size
      matrix = new(data.size, cols, 0.0)
      data.each_with_index do |row, i|
        raise ArgumentError, "row #{i} width #{row.size} != #{cols}" unless row.size == cols

        row.each_with_index { |value, j| matrix.set(i, j, value) }
      end
      matrix
    end

    def [](row)
      @data[row]
    end

    def []=(row, arr)
      @data[row] = arr
    end

    # self × vector. vector — массив длины cols.
    def dot(vector)
      raise ArgumentError, "Dimension mismatch: #{@cols} != #{vector.length}" if @cols != vector.length

      @data.map do |row|
        row.each_with_index.sum { |val, i| val * vector[i] }.to_f
      end
    end

    def at(row, col)
      @data[row][col]
    end

    def set(row, col, val)
      @data[row][col] = val.to_f
    end

    def sum
      @data.flatten.sum.to_f
    end

    def count_nonzero
      @data.sum { |row| row.count { |val| val != 0.0 } }
    end

    def row_array(row)
      @data[row].dup
    end

    def to_a
      @data.map(&:dup)
    end

    def inspect
      "#<SimpleMatrix #{@rows}x#{@cols}>"
    end
  end
end
