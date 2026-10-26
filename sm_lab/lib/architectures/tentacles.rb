# Tentacles — захват передаётся по кругу щупалец.
#
# Следующее щупальце слушает текущее, предыдущее им тормозится.
# Ядро только замечает, кто схватил, и не раздаёт этот сигнал всем:
# иначе вспыхнули бы все щупальца сразу.

module SmLab
  class Tentacles < Network
    CORE_LISTEN = 0.35

    attr_reader :core_size

    def initialize(name: 'Tentacles', neuron_count: 12, **options)
      super(name: name, neuron_count: neuron_count, **Dynamics.wave(options))
      @core_size = if neuron_count <= 2
                     1
                   else
                     [[neuron_count / 5, 1].max, neuron_count - 2].min
                   end
    end

    def build_topology
      @weights = Array.new(size) { Array.new(size, 0.0) }
      arms = tentacle_indexes
      if arms.size >= 2
        arms.each_with_index do |arm, index|
          nxt = arms[(index + 1) % arms.size]
          previous = arms[(index - 1) % arms.size]
          @weights[nxt][arm] = Dynamics::CRAWL_FORWARD
          @weights[previous][arm] = Dynamics::CRAWL_BACK if previous != nxt
        end
      end

      core_indexes.each do |core_index|
        arms.each { |arm| @weights[core_index][arm] = CORE_LISTEN }
      end
    end

    def core_indexes
      (0...@core_size).to_a
    end

    def tentacle_indexes
      (@core_size...size).to_a
    end

    def crawl_order
      tentacle_indexes
    end

    def pulse_index
      tentacle_indexes.first || 0
    end

    def drive_at(step)
      Dynamics.pulse_drive(size, pulse_index, step)
    end

    def layout
      points = Array.new(size)
      @core_size.times do |index|
        angle = 2 * Math::PI * index / [@core_size, 1].max
        points[index] = [0.35 * Math.cos(angle), 0.35 * Math.sin(angle)]
      end
      arms = size - @core_size
      return points if arms.zero?

      arms.times do |index|
        angle = 2 * Math::PI * index / arms
        points[@core_size + index] = [1.3 * Math.cos(angle), 1.3 * Math.sin(angle)]
      end
      points
    end
  end
end
