# Labyrinth — горб ползёт по тропе, телепорт его не кормит.
#
# Следующая клетка возбуждается, предыдущая тормозится.
# Телепорт — тормозной прыжок вдаль: чужая клетка проседает,
# а пик остаётся на соседнем шаге тропы.

module SmLab
  class Labyrinth < Network
    TELEPORT = -0.7
    SEED = 777

    def initialize(name: 'Labyrinth', neuron_count: 10, seed: SEED, **options)
      @seed = seed
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
      end
      return if n < 6

      rng = Random.new(@seed)
      n.times do |index|
        target = (index + 4 + rng.rand(3)) % n
        next if target == index || target == (index + 1) % n || target == (index - 1 + n) % n

        @weights[target][index] += TELEPORT
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
      n = size
      n.times.map do |index|
        fold = (index / 4) % 2
        [index * 0.7, fold.zero? ? (index % 4) * 0.5 : (3 - (index % 4)) * 0.5]
      end
    end
  end
end
