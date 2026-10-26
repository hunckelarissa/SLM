# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Однонаправленное кольцо 0→1→…→n→0.
    #
    # Пока вход удерживается, волна бежит по кольцу. Если подавать кадры через
    # forward_sequence и поставить линейную активацию с весом 1, кольцо становится
    # линией задержки: импульс появляется на нейроне k ровно через k тактов.
    class Ring < SnailNetwork
      include ConnectionHelpers

      SIZE = 10

      def build_topology
        @neurons = create_neurons(ring_size)
        ring_size.times do |index|
          connect(@neurons[index], @neurons[(index + 1) % ring_size])
        end
      end

      def default_input_indices
        [0, 1]
      end

      def default_output_indices
        [ring_size - 2, ring_size - 1]
      end

      private

      def ring_size
        Integer(@config.fetch(:size, SIZE))
      end
    end
  end
end
