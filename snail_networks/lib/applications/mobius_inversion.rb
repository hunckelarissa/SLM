# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Сравнение кольца и ленты Мёбиуса на одном и том же импульсе.
    #
    # Линейная активация и вес 1 превращают обход в сдвиг. Через длину ленты
    # импульс возвращается в стартовый нейрон: у кольца как +1, у ленты как −1.
    # Так можно ловить нечётное число переворотов ориентации — например,
    # противофазу в замкнутом тракте датчика.
    class MobiusInversion
      SIZE = 4

      def self.run
        frames = Array.new(SIZE + 1) { |time| [time.zero? ? 1.0 : 0.0] }
        ring = trace(build_ring, frames)
        mobius = trace(build_mobius, frames)
        ring_return = ring[SIZE][0]
        mobius_return = mobius[SIZE][0]
        success = (ring_return - 1.0).abs < 1e-9 && (mobius_return + 1.0).abs < 1e-9

        Result.new(
          name: "Инверсия ориентации (MobiusStrip)",
          success: success,
          summary: format("после обхода кольцо %+.1f, лента Мёбиуса %+.1f", ring_return, mobius_return),
          details: { ring: ring.map(&:first), mobius: mobius.map(&:first) }
        )
      end

      def self.build_ring
        prepare(Topologies::Ring.new(common_config))
      end

      def self.build_mobius
        prepare(Topologies::MobiusStrip.new(common_config))
      end

      def self.common_config
        {
          size: SIZE,
          input_indices: [0],
          output_indices: (0...SIZE).to_a,
          activation: :linear,
          settle_steps: SIZE,
          seed: 1,
          log: false
        }
      end

      def self.prepare(network)
        network.synapses.each { |synapse| synapse.weight = 1.0 }
        network.neurons.each { |neuron| neuron.bias = 0.0 }
        network
      end

      def self.trace(network, frames)
        network.forward_sequence(frames)
      end
    end
  end
end
