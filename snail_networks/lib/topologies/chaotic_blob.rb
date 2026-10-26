# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Случайный ориентированный граф: контрольная топология «без замысла».
    #
    # Каркас — кольцо, поэтому из каждого нейрона можно дойти до каждого,
    # а диаметр ограничен размером сети. Поверх каркаса каждому нейрону
    # добавляются случайные входы, пока их не станет 3 или 4.
    # Генератор берётся из seed конфигурации, так что граф повторяем.
    class ChaoticBlob < SnailNetwork
      include ConnectionHelpers

      SIZE = 20
      MIN_INPUTS = 3
      MAX_INPUTS = 4

      def build_topology
        @neurons = create_neurons(blob_size)

        blob_size.times do |index|
          connect(@neurons[index], @neurons[(index + 1) % blob_size])
        end

        @neurons.each do |target|
          existing = target.incoming.map { |synapse| synapse.source.index }
          extra = @rng.rand(MIN_INPUTS..MAX_INPUTS) - existing.size
          next if extra <= 0

          pool = @neurons.reject { |neuron| neuron.index == target.index || existing.include?(neuron.index) }
          pool.shuffle(random: @rng).take(extra).each { |source| connect(source, target) }
        end
      end

      def default_input_indices
        [0, 1, 2]
      end

      def default_output_indices
        size = blob_size
        [size - 3, size - 2, size - 1]
      end

      private

      def blob_size
        Integer(@config.fetch(:size, SIZE))
      end
    end
  end
end
