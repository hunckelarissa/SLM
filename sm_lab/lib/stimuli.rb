# Stimuli — внешние сигналы для экспериментов.
# Один и тот же шаг и размер сети дают один и тот же вектор:
# архитектуры сравниваются на общем входе, без глобального rand.

module SmLab
  module Stimuli
    TYPES = %i[random periodic center_pulse spiral alternating silence tonic].freeze

    def self.generate(type, n, step, level: 0.4)
      kind = type.to_sym
      unless TYPES.include?(kind)
        raise ArgumentError, "unknown stimulus #{type.inspect}; use #{TYPES.join(', ')}"
      end
      raise ArgumentError, 'stimulus length must be positive' unless n.is_a?(Integer) && n.positive?

      case kind
      when :random
        rng = Random.new(10_000 + step)
        Array.new(n) { rng.rand(0.2..0.5) }
      when :periodic
        value = Math.sin(step * 0.3) * 0.3 + 0.3
        Array.new(n, value)
      when :center_pulse
        pulse = Array.new(n, 0.1)
        pulse[n / 2] = 0.8
        pulse
      when :spiral
        value = ((step + (n % 3)) * 0.1) % 0.5
        Array.new(n, value)
      when :alternating
        Array.new(n, step.even? ? 0.1 : 0.7)
      when :silence
        Array.new(n, 0.0)
      when :tonic
        Array.new(n, level.to_f)
      end
    end
  end
end
