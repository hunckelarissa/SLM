# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Топология «Кольца вложенные».
    #
    # 3 концентрических кольца по 6 нейронов (всего 18), плюс радиальные
    # связи между кольцами. Внутри каждого кольца — однонаправленные связи
    # по кругу. Между кольцами — двунаправленные радиальные связи.
    #
    # Философия: вложенные кольца создают «слои» циркуляции. Внутреннее кольцо
    # — ядро, внешние — периферия. Радиальные связи позволяют информации
    # течь между уровнями, а кольцевые — циркулировать внутри уровня.
    # Моделирует иерархическую рекуррентную структуру.
    class NestedRings < SnailNetwork
      include ConnectionHelpers

      RINGS = 3
      PER_RING = 6

      def build_topology
        @neurons = create_neurons(RINGS * PER_RING)

        # Кольцевые связи внутри каждого кольца.
        RINGS.times do |ring|
          PER_RING.times do |i|
            current = ring * PER_RING + i
            nxt = ring * PER_RING + ((i + 1) % PER_RING)
            connect(@neurons[current], @neurons[nxt])
          end
        end

        # Радиальные связи между соседними кольцами.
        (RINGS - 1).times do |ring|
          PER_RING.times do |i|
            inner = ring * PER_RING + i
            outer = (ring + 1) * PER_RING + i
            connect_bidirectional(@neurons[inner], @neurons[outer])
          end
        end
      end

      def default_input_indices
        [0, 1]
      end

      def default_output_indices
        [16, 17]
      end
    end
  end
end