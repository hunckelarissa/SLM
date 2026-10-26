# Dynamics — общие настройки и оценки ритма.
#
# Осциллятор — те же числа, что у генератора шага: самовозбуждение
# около 2.5, взаимное торможение около -4 и тонический вход 3.5.
# Усталость гасит победителя, и группы сменяют друг друга.

module SmLab
  module Dynamics
    OSCILLATOR = {
      bias: 0.5,
      threshold: 0.5,
      slope: 2.5,
      fatigue_gain: 0.12,
      fatigue_sensitivity: 0.4,
      fatigue_pull: 3.0
    }.freeze

    TONIC = 3.5
    SELF_EXCITATION = 2.5
    RECIPROCAL_INHIBITION = -4.0

    # Тихий покой и сильный шаг вперёд: горб ползёт на одну клетку за такт.
    WAVE = {
      bias: 1.8,
      threshold: 0.5,
      slope: 2.0,
      fatigue_gain: 0.01,
      fatigue_sensitivity: 0.2,
      fatigue_pull: 0.0
    }.freeze
    PULSE = 3.2
    CRAWL_FORWARD = 4.5
    CRAWL_BACK = -1.5

    module_function

    # options архитектуры перекрывают пресет, неизвестные ключи
    # (seed и т.п.) проходят в Network как есть.
    def tune(options = {})
      extras = options.dup
      neuron_overrides = extras.delete(:neuron_options) || {}
      recover_rate = extras.delete(:recover_rate)
      homeostasis_rate = extras.delete(:homeostasis_rate)
      {
        neuron_options: OSCILLATOR.merge(neuron_overrides),
        recover_rate: recover_rate.nil? ? 0.1 : recover_rate,
        homeostasis_rate: homeostasis_rate.nil? ? 0.0 : homeostasis_rate
      }.merge(extras)
    end

    def wave(options = {})
      extras = options.dup
      neuron_overrides = extras.delete(:neuron_options) || {}
      recover_rate = extras.delete(:recover_rate)
      homeostasis_rate = extras.delete(:homeostasis_rate)
      {
        neuron_options: WAVE.merge(neuron_overrides),
        recover_rate: recover_rate.nil? ? 0.2 : recover_rate,
        homeostasis_rate: homeostasis_rate.nil? ? 0.0 : homeostasis_rate
      }.merge(extras)
    end

    def kick(network, high:, low: [], high_level: 0.9, low_level: 0.12)
      high.each do |index|
        network.neurons[index].activation = high_level
        network.neurons[index].fatigue = 0.02
      end
      low.each do |index|
        network.neurons[index].activation = low_level
        network.neurons[index].fatigue = 0.2
      end
      network
    end

    def trace(network, steps:, drive:)
      steps.times.map do
        network.step!(external_input: drive, homeostasis: false)
        network.neurons.map(&:activation)
      end
    end

    def uniform_drive(size, level = TONIC)
      Array.new(size, level)
    end

    def mean_series(frames, indexes)
      frames.map do |row|
        indexes.sum { |index| row[index] }.fdiv(indexes.size)
      end
    end

    def opposed_fraction(left, right, margin: 0.25)
      return 0.0 if left.empty?

      left.zip(right).count { |a_val, b_val| (a_val - b_val).abs > margin }.fdiv(left.size)
    end

    def flips(left, right)
      signs = left.zip(right).map { |a_val, b_val| a_val > b_val }
      signs.each_cons(2).count { |before, after| before != after }
    end

    # Две группы: внутри возбуждение с суммой 2.5, между ними торможение с суммой -4.
    def couple_populations(weights, left, right)
      [left, right].each do |group|
        if group.size == 1
          weights[group[0]][group[0]] = SELF_EXCITATION
        elsif group.size > 1
          share = SELF_EXCITATION / (group.size - 1)
          group.each do |i|
            group.each { |j| weights[i][j] = share if i != j }
          end
        end
      end
      return if left.empty? || right.empty?

      from_right = RECIPROCAL_INHIBITION / right.size
      from_left = RECIPROCAL_INHIBITION / left.size
      left.each { |i| right.each { |j| weights[i][j] = from_right } }
      right.each { |i| left.each { |j| weights[i][j] = from_left } }
    end

    def forward_steps(frames, neuron_count)
      peaks = frames.map { |row| row.each_with_index.max_by { |value, _index| value }.last }
      peaks.each_cons(2).count { |before, after| after == (before + 1) % neuron_count }
    end

    def pulse_drive(size, index, step, level = PULSE)
      drive = Array.new(size, 0.0)
      drive[index] = level if step.zero? && !index.nil?
      drive
    end

    def crawl(network, steps:)
      steps.times.map do |step|
        network.step!(external_input: network.drive_at(step), homeostasis: false)
        network.neurons.map(&:activation)
      end
    end

    # peaks — идентификаторы в порядке обхода. Доля шагов, где пик сдвинулся на одну позицию.
    def advance_fraction(peaks, order)
      return 0.0 if peaks.size < 2

      place = order.each_with_index.to_h
      peaks.each_cons(2).count do |before, after|
        place[after] == (place[before] + 1) % order.size
      end.fdiv(peaks.size - 1)
    end
  end
end
