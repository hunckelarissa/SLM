# ChaoticBall — случайный граф. Часть нейронов только тормозит.
#
# Знак исходящих связей зависит от номера нейрона, не от броска:
# каждый четвёртый — тормозной. Генератор локальный, seed тот же,
# глобальный rand процесса не сдвигается.

module SmLab
  class ChaoticBall < Network
    DENSITY = 0.25
    BREAK_PROB = 0.30
    WEIGHT_SCALE = 1.0
    SEED = 42

    def initialize(name: 'ChaoticBall', neuron_count: 10, seed: SEED, **options)
      @seed = seed
      super(name: name, neuron_count: neuron_count, **options)
    end

    def build_topology
      n = size
      @weights = Array.new(n) { Array.new(n, 0.0) }
      rng = Random.new(@seed)

      n.times do |i|
        n.times do |j|
          next if i == j
          next unless rng.rand < DENSITY

          weight = rng.rand < BREAK_PROB ? 0.0 : rng.rand(0.0..WEIGHT_SCALE).round(4)
          @weights[i][j] = weight
        end
      end

      n.times do |i|
        next if @weights[i].any? { |weight| weight != 0.0 }
        next if n < 2

        candidates = (0...n).to_a - [i]
        @weights[i][candidates[rng.rand(candidates.size)]] = 0.5
      end

      n.times do |i|
        next unless inhibitory?(i)

        @weights[i].map! { |weight| -weight.abs }
      end
    end

    def inhibitory?(index)
      (index % 4).zero?
    end

    def layout
      n = size
      n.times.map do |i|
        angle = 2 * Math::PI * i / n
        [Math.cos(angle), Math.sin(angle)]
      end
    end
  end
end
