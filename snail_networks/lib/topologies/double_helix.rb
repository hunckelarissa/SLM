# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Топология «Двойная спираль».
    #
    # 14 нейронов (по 7 на каждую спираль). Внутри каждой спирали — связи
    # последовательные (0→1→…→6 и 7→8→…→13). Плюс перемычки между спиралями
    # на каждом витке (нейрон i первой спирали связан с нейроном i второй).
    #
    # Философия: двойная спираль — модель ДНК. Две «нити» передают сигнал
    # последовательно, а перемычки (водородные связи) связывают нити попарно.
    # Это создаёт два параллельных канала с перекрёстным обменом информацией.
    class DoubleHelix < SnailNetwork
      include ConnectionHelpers

      PER_HELIX = 7

      def build_topology
        @neurons = create_neurons(2 * PER_HELIX)

        # Последовательные связи внутри каждой спирали.
        2.times do |helix|
          base = helix * PER_HELIX
          (PER_HELIX - 1).times do |i|
            connect(@neurons[base + i], @neurons[base + i + 1])
          end
        end

        # Перемычки между спиралями на каждом витке.
        PER_HELIX.times do |i|
          connect_bidirectional(@neurons[i], @neurons[PER_HELIX + i])
        end
      end

      def default_input_indices
        [0, 7]
      end

      def default_output_indices
        [6, 13]
      end
    end
  end
end