# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Топология «Спираль».
    #
    # 12 нейронов, расположенных по спирали Архимеда. Каждый нейрон соединён
    # с ближайшим соседом по спирали (последовательная цепочка), плюс есть
    # «перемычки» — связи между соседними витками спирали.
    #
    # Философия: спираль сочетает локальную последовательную передачу сигнала
    # (как в кольце) с «короткими замыканиями» между витками. Это создаёт
    # иерархию задержек: сигнал может идти по длинному пути или прыгать через
    # виток. Моделирует структуру, похожую на свёрнутую ДНК.
    class Spiral < SnailNetwork
      include ConnectionHelpers

      SIZE = 12
      TURNS = 3 # число витков спирали

      def build_topology
        @neurons = create_neurons(SIZE)

        # Последовательная цепочка по спирали.
        (SIZE - 1).times do |i|
          connect(@neurons[i], @neurons[i + 1])
        end

        # Перемычки между соседними витками.
        # Нейрон на витке k соединён с нейроном на витке k+1, отстоящим на
        # один «шаг витка» (SIZE / TURNS).
        step = SIZE / TURNS
        (SIZE - step).times do |i|
          connect(@neurons[i], @neurons[i + step])
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