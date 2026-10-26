# frozen_string_literal: true

module SnailNetwork
  # Синапс — направленное соединение source → target.
  #
  # +flip_sign+ меняет знак эффективного веса. Лента Мёбиуса использует это
  # на замыкающем ребре: сигнал, обошедший ленту, возвращается инвертированным.
  class Synapse
    attr_accessor :weight
    attr_reader :source, :target, :flip_sign

    # @param source [Neuron]
    # @param target [Neuron]
    # @param weight [Float, nil] nil — случайное значение из rng
    # @param flip_sign [Boolean]
    # @param rng [Random]
    def initialize(source:, target:, weight: nil, flip_sign: false, rng: Random.new)
      @source = source
      @target = target
      @weight = weight.nil? ? rng.rand(-1.0..1.0) : weight.to_f
      @flip_sign = flip_sign
    end

    # Вес с учётом переворота знака.
    # @return [Float]
    def effective_weight
      flip_sign ? -@weight : @weight
    end

    # Вклад в сумму целевого нейрона.
    # @return [Float]
    def fire
      effective_weight * @source.activation
    end

    # @return [Hash]
    def to_h
      {
        source: @source.index,
        target: @target.index,
        weight: @weight,
        flip_sign: @flip_sign
      }
    end
  end
end
