# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Кольцо, у которого замыкающее ребро переворачивает знак веса.
    #
    # После полного обхода сигнал возвращается во входной нейрон с обратным
    # знаком. У обычного кольца того же размера знак сохраняется. Чтобы возврат
    # был виден, входной нейрон должен принимать и рекуррентный член, и внешний
    # кадр — иначе перевёрнутое ребро упирается в навсегда зажатый вход.
    class MobiusStrip < SnailNetwork
      include ConnectionHelpers

      SIZE = 12

      def build_topology
        @neurons = create_neurons(strip_size)
        strip_size.times do |index|
          nxt = (index + 1) % strip_size
          connect(@neurons[index], @neurons[nxt], flip_sign: index == strip_size - 1)
        end
      end

      def default_input_indices
        [0, 1]
      end

      def default_output_indices
        [strip_size - 2, strip_size - 1]
      end

      private

      def strip_size
        Integer(@config.fetch(:size, SIZE))
      end
    end
  end
end