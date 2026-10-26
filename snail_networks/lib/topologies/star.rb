# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Топология «Звезда».
    #
    # 1 центральный нейрон + 8 периферийных. Связи только центр ↔ периферия
    # (двунаправленные). Периферийные нейроны не связаны между собой.
    #
    # Философия: звезда — это «хаб» с максимальной централизацией. Весь сигнал
    # обязан проходить через центральный нейрон, который становится узким
    # местом и «дирижёром». Идеальна для изучения роли центрального узла
    # (bottleneck) в обработке информации.
    class Star < SnailNetwork
      include ConnectionHelpers

      CENTER = 0
      PERIPHERY = 8

      def build_topology
        @neurons = create_neurons(1 + PERIPHERY)

        (1..PERIPHERY).each do |i|
          connect_bidirectional(@neurons[CENTER], @neurons[i])
        end
      end

      def default_input_indices
        [1, 2]
      end

      def default_output_indices
        [7, 8]
      end
    end
  end
end