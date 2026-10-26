# frozen_string_literal: true

require_relative "../snail_network"
require_relative "connection_helpers"

module SnailNetwork
  module Topologies
    # Три кольца по пять позиций с общим ядром из трёх нейронов.
    #
    # Уникальных нейронов девять: ядро 0, 1, 2 и по два нейрона на лепесток.
    # Рёбра ядра 0→1→2→0 создаются один раз. Раньше они копировались в каждый
    # лепесток, и сигнал по ядру шёл тройной силой.
    #
    # Вход подаётся в ядро, выход снимается с внешнего нейрона каждого лепестка.
    # Так три цикла делят общий узел, но ответ лепестка не зажат входным значением.
    class Clover < SnailNetwork
      include ConnectionHelpers

      CORE = 3
      PER_LEAF = 2
      LEAVES = 3

      def build_topology
        @neurons = create_neurons(CORE + (LEAVES * PER_LEAF))

        connect(@neurons[0], @neurons[1])
        connect(@neurons[1], @neurons[2])
        connect(@neurons[2], @neurons[0])

        LEAVES.times do |leaf|
          first = CORE + (leaf * PER_LEAF)
          second = first + 1
          # 0 → свой лепесток → 1, дальше общий путь ядра 1→2→0.
          connect(@neurons[0], @neurons[first])
          connect(@neurons[first], @neurons[second])
          connect(@neurons[second], @neurons[1])
        end
      end

      def default_input_indices
        [0, 1, 2]
      end

      def default_output_indices
        LEAVES.times.map { |leaf| CORE + (leaf * PER_LEAF) + 1 }
      end
    end
  end
end
