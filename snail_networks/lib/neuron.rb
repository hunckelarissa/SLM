# frozen_string_literal: true

module SnailNetwork
  # Нейрон — базовый вычислительный элемент «улитки».
  #
  # Состояние:
  #   * activation     — выход функции активации;
  #   * input_sum      — взвешенная сумма входящих синапсов (без смещения);
  #   * bias           — обучаемое смещение;
  #   * pre_activation — аргумент функции активации на последнем шаге.
  #
  # Сначала все нейроны читают activation предыдущего шага (compute_input_sum),
  # затем все одновременно обновляют activation. Так циклические топологии
  # остаются корректными.
  class Neuron
    ACTIVATIONS = {
      tanh: {
        fn: ->(x) { Math.tanh(x) },
        derivative: ->(y) { 1.0 - (y * y) }
      },
      sigmoid: {
        fn: ->(x) { 1.0 / (1.0 + Math.exp(-x.clamp(-60.0, 60.0))) },
        derivative: ->(y) { y * (1.0 - y) }
      },
      # Ограничение не даёт рекуррентному линейному проходу уйти в бесконечность.
      # На решениях с амплитудой около 1 оно не срабатывает.
      linear: {
        fn: ->(x) { x.clamp(-6.0, 6.0) },
        derivative: ->(y) { y.abs >= 6.0 ? 0.0 : 1.0 }
      }
    }.freeze

    attr_accessor :activation, :input_sum, :bias
    attr_reader :index, :incoming, :outgoing, :pre_activation, :activation_name

    # @param index [Integer]
    # @param activation [Symbol, String] :tanh, :sigmoid или :linear
    # @param bias [Float]
    def initialize(index, activation: :tanh, bias: 0.0)
      name = activation.to_sym
      spec = ACTIVATIONS.fetch(name) do
        raise ArgumentError, "Неизвестная функция активации: #{activation.inspect}"
      end

      @index = index
      @activation = 0.0
      @input_sum = 0.0
      @pre_activation = 0.0
      @bias = bias.to_f
      @incoming = []
      @outgoing = []
      @activation_name = name
      @activation_fn = spec[:fn]
      @derivative_fn = spec[:derivative]
    end

    # @param synapse [Synapse]
    def add_incoming(synapse)
      @incoming << synapse
    end

    # @param synapse [Synapse]
    def add_outgoing(synapse)
      @outgoing << synapse
    end

    # Взвешенная сумма входов по активациям предыдущего шага.
    # @return [Float]
    def compute_input_sum
      @input_sum = @incoming.sum(&:fire)
    end

    # Обновить активацию. +extra+ — внешний сигнал, который добавляется
    # к рекуррентной сумме (входные нейроны с обратными связями).
    # @param extra [Float]
    # @return [Float]
    def activate(extra = 0.0)
      @pre_activation = @input_sum + @bias + extra.to_f
      @activation = @activation_fn.call(@pre_activation)
    end

    # Выставить активацию напрямую. Так устроены проходные входы без
    # входящих синапсов: наружу уходит само значение, а не f(значение).
    # @param value [Numeric]
    # @return [Float]
    def force_activation(value)
      @input_sum = 0.0
      @pre_activation = value.to_f
      @activation = value.to_f
    end

    # Производная по уже посчитанному выходу. На границе линейного ограничения
    # градиент обнуляется, внутри отрезка линейная функция имеет производную 1.
    # @param activation [Float]
    # @return [Float]
    def derivative_for(activation)
      @derivative_fn.call(activation)
    end

    # Производная активации на последнем шаге.
    # @return [Float]
    def activation_derivative
      derivative_for(@activation)
    end

    # Сбросить динамическое состояние. Смещение и связи сохраняются.
    def reset
      @activation = 0.0
      @input_sum = 0.0
      @pre_activation = 0.0
    end
  end
end
