# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Топология «Сфера».
    #
    # 12 нейронов на поверхности икосаэдра. Каждый нейрон соединён с 5
    # ближайшими соседями (вершины икосаэдра имеют степень 5). Связи
    # двунаправленные.
    #
    # Философия: икосаэдр — это максимально «симметричная» конечная сеть:
    # все нейроны эквивалентны (регулярный граф степени 5). Нет выделенных
    # краёв или центра. Сигнал распространяется равномерно во все стороны,
    # что делает сферу идеальной для изучения симметричной диффузии.
    class Sphere < SnailNetwork
      include ConnectionHelpers

      # Рёбра икосаэдра (12 вершин, 30 рёбер). Каждая вершина имеет степень 5.
      EDGES = [
        [0, 1], [0, 2], [0, 3], [0, 4], [0, 5],
        [1, 2], [1, 5], [1, 6], [1, 7],
        [2, 3], [2, 7], [2, 8],
        [3, 4], [3, 8], [3, 9],
        [4, 5], [4, 9], [4, 10],
        [5, 6], [5, 10],
        [6, 7], [6, 10], [6, 11],
        [7, 8], [7, 11],
        [8, 9], [8, 11],
        [9, 10], [9, 11],
        [10, 11]
      ].freeze

      def build_topology
        @neurons = create_neurons(12)

        EDGES.each do |a, b|
          connect_bidirectional(@neurons[a], @neurons[b])
        end
      end

      def default_input_indices
        [0, 1]
      end

      def default_output_indices
        [10, 11]
      end
    end
  end
end