# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Решётка 4×4. Соседи по стороне связаны в обе стороны, края не склеены.
    #
    # У угла две связи, у края три, у внутренней клетки четыре. Граф цикличный:
    # активность диффундирует по поверхности и может возвращаться. От верхнего
    # ряда до нижнего три ребра, поэтому settle_steps меньше трёх отрезает выход
    # от входа.
    class FlatSquare < SnailNetwork
      include ConnectionHelpers

      SIZE = 4

      def build_topology
        side = grid_size
        @neurons = create_neurons(side * side)

        side.times do |row|
          side.times do |col|
            index = (row * side) + col
            connect(@neurons[index], @neurons[((row - 1) * side) + col]) if row.positive?
            connect(@neurons[index], @neurons[((row + 1) * side) + col]) if row < side - 1
            connect(@neurons[index], @neurons[(row * side) + col - 1]) if col.positive?
            connect(@neurons[index], @neurons[(row * side) + col + 1]) if col < side - 1
          end
        end
      end

      def default_input_indices
        (0...grid_size).to_a
      end

      def default_output_indices
        side = grid_size
        ((side * (side - 1))...(side * side)).to_a
      end

      private

      def grid_size
        Integer(@config.fetch(:size, SIZE))
      end
    end
  end
end
