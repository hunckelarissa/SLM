# frozen_string_literal: true

module SnailNetwork
  module Topologies
    # Общие операции построения графа. Подмешиваются в каждую топологию.
    module ConnectionHelpers
      # Однонаправленный синапс source → target.
      # Вес по умолчанию берётся из генератора сети, а не из глобального rand,
      # чтобы seed в конфигурации воспроизводил и граф, и начальные веса.
      #
      # @param source [Neuron]
      # @param target [Neuron]
      # @param weight [Float, nil]
      # @param flip_sign [Boolean]
      # @return [Synapse]
      def connect(source, target, weight: nil, flip_sign: false)
        drawn = weight.nil? ? @rng.rand(-1.0..1.0) : weight
        synapse = Synapse.new(source: source, target: target, weight: drawn, flip_sign: flip_sign)
        source.add_outgoing(synapse)
        target.add_incoming(synapse)
        @synapses << synapse
        synapse
      end

      # Два встречных синапса. Это не одно неориентированное ребро:
      # у каждого направления свой вес.
      # @param a [Neuron]
      # @param b [Neuron]
      def connect_bidirectional(a, b)
        connect(a, b)
        connect(b, a)
      end

      # @param count [Integer]
      # @return [Array<Neuron>]
      def create_neurons(count)
        activation = (@config[:activation] || :tanh).to_sym
        count.times.map { |i| Neuron.new(i, activation: activation) }
      end
    end
  end
end
