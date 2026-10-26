# Neuron — атомарная единица «жизни» в SMLab.

module SmLab

  # === Neuron ===
  #
  # Каждый нейрон — мини-существо:
  #   - activation — возбуждение (0..1)
  #   - fatigue    — усталость (0..1), копится от активности и утекает
  #   - threshold  — порог состояний active / dormant
  #   - bias       — сдвиг покоя: нулевой вход ниже порога
  #
  # Усталость и порог дают адаптацию без градиентов. Сильный
  # fatigue_pull превращает пару нейронов в релаксационный осциллятор.

  class Neuron
    attr_reader :id, :activation, :fatigue, :threshold, :state,
                :bias, :slope, :fatigue_gain, :fatigue_sensitivity, :fatigue_pull
    attr_writer :fatigue

    def initialize(id:, threshold: 0.5, bias: 1.1, slope: 1.0,
                   fatigue_gain: 0.06, fatigue_sensitivity: 0.75, fatigue_pull: 0.0)
      raise ArgumentError, 'slope must be positive' unless slope.is_a?(Numeric) && slope.positive?

      @id = id
      @activation = 0.0
      @fatigue = 0.0
      @threshold = threshold
      @bias = bias.to_f
      @slope = slope.to_f
      @fatigue_gain = fatigue_gain.to_f
      @fatigue_sensitivity = fatigue_sensitivity.to_f
      @fatigue_pull = fatigue_pull.to_f
      @state = :dormant
    end

    def activation=(value)
      @activation = value.to_f
      refresh_state
    end

    # Сигмоида от входа. Усталость глушит вход и, если задан
    # fatigue_pull, дополнительно уводит нейрон в покой.
    def activate!(input)
      dampener = 1.0 - (@fatigue_sensitivity * @fatigue)
      dampener = 0.05 if dampener < 0.05
      raw = ((input.to_f * dampener) - @bias - (@fatigue_pull * @fatigue)) * @slope
      @activation = sigmoid(raw)
      @fatigue = (@fatigue + (@fatigue_gain * @activation)).clamp(0.0, 1.0)
      refresh_state
      self
    end

    # Утечка усталости. Состояние возбуждения не трогаем:
    # его определяет активация, а не отдых.
    def recover(rate: 0.1)
      leak = rate.to_f.clamp(0.0, 1.0)
      @fatigue = (@fatigue * (1.0 - leak)).clamp(0.0, 1.0)
      self
    end

    # Слабый сдвиг активации к target. rate — доля разрыва за вызов.
    def homeostatic_clamp(target: 0.5, rate: 0.1)
      @activation = (@activation + ((target.to_f - @activation) * rate.to_f)).clamp(0.0, 1.0)
      refresh_state
      self
    end

    def to_h
      {
        id: @id,
        activation: @activation.round(6),
        fatigue: @fatigue.round(6),
        threshold: @threshold,
        state: @state.to_s
      }
    end

    def inspect
      "#<Neuron id=#{@id} act=#{@activation.round(4)} " \
        "fat=#{@fatigue.round(4)} state=#{@state}>"
    end

    private

    def refresh_state
      @state = if @activation > 0.7
                 :excited
               elsif @activation > @threshold
                 :active
               else
                 :dormant
               end
    end

    def sigmoid(raw)
      1.0 / (1.0 + Math.exp(-raw.clamp(-20.0, 20.0)))
    end
  end
end
