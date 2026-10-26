# frozen_string_literal: true

module SnailNetwork
  module Applications
    # Кольцо как сдвиговый регистр.
    #
    # Один импульс подаётся в нулевой такт и дальше держится ноль.
    # На нейроне с номером DELAY единица появляется ровно через DELAY тактов.
    # Это короткая память: эхо команды, линия задержки, ожидание маркера в последовательности.
    class RingMemory
      DELAY = 3
      SIZE = 6

      def self.run
        network = Topologies::Ring.new(
          size: SIZE,
          input_indices: [0],
          output_indices: [DELAY],
          activation: :linear,
          settle_steps: DELAY,
          seed: 1,
          log: false
        )
        network.synapses.each { |synapse| synapse.weight = 1.0 }
        network.neurons.each { |neuron| neuron.bias = 0.0 }

        frames = Array.new(DELAY + 1) { |time| [time.zero? ? 1.0 : 0.0] }
        trace = network.forward_sequence(frames).map(&:first)
        arrived_on_time = (trace[DELAY] - 1.0).abs < 1e-9
        silent_before = trace[0...DELAY].all? { |value| value.abs < 1e-9 }

        Result.new(
          name: "Линия задержки (Ring)",
          success: arrived_on_time && silent_before,
          summary: "импульс на выходе по тактам: #{trace.map { |value| format('% .1f', value) }.join(' → ')}",
          details: { trace: trace, delay: DELAY }
        )
      end
    end
  end
end
