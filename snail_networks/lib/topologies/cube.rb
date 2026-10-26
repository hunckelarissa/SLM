# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Топология «Куб».
    #
    # 8 нейронов в вершинах куба. Рёбра куба — двунаправленные связи.
    # Каждая вершина соединена с 3 соседями (по рёбрам).
    #
    # Философия: куб — это трёхмерная решётка с высокой связностью (каждый
    # нейрон имеет 3 соседа) и короткими путями между любыми вершинами
    # (диаметр = 3). Двунаправленность рёбер позволяет сигналу распространяться
    # в обе стороны, создавая богатую динамику отражений.
    class Cube < SnailNetwork
      include ConnectionHelpers

      # Рёбра куба: пары индексов вершин.
      EDGES = [
        [0, 1], [0, 2], [0, 4],
        [1, 3], [1, 5],
        [2, 3], [2, 6],
        [3, 7],
        [4, 5], [4, 6],
        [5, 7],
        [6, 7]
      ].freeze

      def build_topology
        @neurons = create_neurons(8)

        EDGES.each do |a, b|
          connect_bidirectional(@neurons[a], @neurons[b])
        end
      end

      def default_input_indices
        [0, 1]
      end

      def default_output_indices
        [6, 7]
      end
    end
  end
end