# Network — базовый класс конфигураций SMLab.
#
# Шаг дискретный и рекуррентный: новый вход нейрона — это
# строка весов, умноженная на активации ПРОШЛОГО шага,
# плюс внешний сигнал. Так топология действительно живёт во времени.

module SmLab
  class Network
    attr_reader :neurons, :weights, :name, :depth, :width, :step_count, :history,
                :recover_rate, :homeostasis_rate

    def initialize(name:, neuron_count:, neuron_options: {}, recover_rate: 0.08, homeostasis_rate: 0.02)
      unless neuron_count.is_a?(Integer) && neuron_count.positive?
        raise ArgumentError, "neuron_count must be a positive integer, got #{neuron_count.inspect}"
      end

      @name = name
      @neurons = []
      @weights = nil
      @depth = 1
      @width = neuron_count
      @step_count = 0
      @history = []
      @recover_rate = recover_rate.to_f
      @homeostasis_rate = homeostasis_rate.to_f
      @neuron_options = neuron_options

      neuron_count.times do |i|
        @neurons << Neuron.new(id: i, **neuron_options)
      end
    end

    def build_topology
      raise NotImplementedError, "#{self.class.name} must implement build_topology"
    end

    # Координаты нейронов для рисунка. nil, если топология их не задаёт.
    def layout
      nil
    end

    def size
      @neurons.size
    end

    # homeostasis: false отключает притяжение к 0.5 на этот шаг.
    def step!(external_input: nil, homeostasis: true)
      @step_count += 1
      build_topology unless @weights
      validate_weights!

      previous = @neurons.map(&:activation)
      incoming = SimpleMatrix.rows(@weights).dot(previous)
      drive = coerce_input(external_input, size)

      size.times { |i| @neurons[i].activate!(incoming[i] + drive[i]) }
      @neurons.each { |neuron| neuron.recover(rate: @recover_rate) }
      apply_homeostasis if homeostasis && @homeostasis_rate.positive?
      log_state
      self
    end

    def apply_homeostasis(target: 0.5)
      @neurons.each do |neuron|
        neuron.homeostatic_clamp(target: target, rate: @homeostasis_rate)
      end
    end

    def inspect_state
      @neurons.map(&:to_h)
    end

    def mean_activation
      @neurons.sum(&:activation).fdiv(size)
    end

    def mean_fatigue
      @neurons.sum(&:fatigue).fdiv(size)
    end

    def summary_series
      @history.map do |frame|
        states = frame[:state]
        n = states.size.to_f
        {
          step: frame[:step],
          avg_act: states.sum { |item| item[:activation] }.fdiv(n),
          avg_fat: states.sum { |item| item[:fatigue] }.fdiv(n)
        }
      end
    end

    def info
      {
        name: @name,
        neurons: size,
        weights_nonzero: @weights ? nonzero_weights : 0,
        avg_activation: mean_activation.round(4),
        avg_fatigue: mean_fatigue.round(4),
        step_count: @step_count
      }
    end

    def inspect
      "#<#{self.class.name} name=#{@name} neurons=#{size} " \
        "steps=#{@step_count} avg_act=#{mean_activation.round(4)}>"
    end

    def self.slug(name)
      name.to_s
          .gsub('SmLab::', '')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
    end

    def slug
      self.class.slug(@name)
    end

    private

    def validate_weights!
      ok = @weights.is_a?(Array) &&
           @weights.size == size &&
           @weights.all? { |row| row.is_a?(Array) && row.size == size }
      return if ok

      raise ArgumentError, "#{self.class.name}: weight matrix must be #{size}x#{size}"
    end

    def coerce_input(external_input, n)
      return Array.new(n, 0.0) if external_input.nil?
      unless external_input.is_a?(Array) && external_input.size == n
        raise ArgumentError,
              "external_input size #{external_input.respond_to?(:size) ? external_input.size : 'n/a'} " \
              "does not match #{n} neurons"
      end

      external_input.map do |value|
        Float(value)
      rescue ArgumentError, TypeError
        raise ArgumentError, "external_input must be numeric, got #{value.inspect}"
      end
    end

    def nonzero_weights
      @weights.sum { |row| row.count { |weight| weight != 0.0 } }
    end

    def log_state
      @history << { step: @step_count, state: inspect_state }
    end
  end
end
