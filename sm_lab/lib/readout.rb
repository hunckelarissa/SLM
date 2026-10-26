# Readout — линейный считыватель поверх живой сети.
# Учится только он. Сам организм градиентов не видит.

module SmLab
  module Readout
    module_function

    def fit(samples, labels, lambda: 0.05)
      raise ArgumentError, 'readout needs samples' if samples.empty?

      rows = samples.map { |sample| sample.map(&:to_f) + [1.0] }
      dim = rows.first.size
      ata = Array.new(dim) { Array.new(dim, 0.0) }
      atb = Array.new(dim, 0.0)

      rows.zip(labels) do |features, label|
        y = label.to_f
        dim.times do |i|
          atb[i] += features[i] * y
          dim.times { |j| ata[i][j] += features[i] * features[j] }
        end
      end
      dim.times { |i| ata[i][i] += lambda }
      solve(ata, atb)
    end

    def predict(weights, sample)
      features = sample.map(&:to_f) + [1.0]
      features.zip(weights).sum { |feature, weight| feature * weight }
    end

    def classify(weights, sample)
      predict(weights, sample) >= 0.5 ? 1 : 0
    end

    def solve(matrix, vector)
      n = vector.size
      rows = matrix.each_with_index.map { |row, i| row.dup << vector[i].to_f }
      n.times do |col|
        pivot = (col...n).max_by { |row| rows[row][col].abs }
        raise ArgumentError, 'readout matrix is singular' if rows[pivot][col].abs < 1e-10

        rows[col], rows[pivot] = rows[pivot], rows[col]
        scale = rows[col][col]
        rows[col].map! { |value| value / scale }
        n.times do |row|
          next if row == col

          factor = rows[row][col]
          (col..n).each { |cursor| rows[row][cursor] -= factor * rows[col][cursor] }
        end
      end
      rows.map { |row| row[n] }
    end
  end
end
