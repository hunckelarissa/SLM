# frozen_string_literal: true

# Главная точка входа в библиотеку Snail Networks.
# Загружает все классы и делает их доступными через модуль SnailNetwork.

require_relative "snail_network"
require_relative "neuron"
require_relative "synapse"
require_relative "network_builder"
require_relative "visualizer"
require_relative "topologies/connection_helpers"
require_relative "topologies/flat_square"
require_relative "topologies/ring"
require_relative "topologies/spiral"
require_relative "topologies/cube"
require_relative "topologies/chaotic_blob"
require_relative "topologies/layered"
require_relative "topologies/nested_rings"
require_relative "topologies/sphere"
require_relative "topologies/star"
require_relative "topologies/double_helix"
require_relative "topologies/clover"
require_relative "topologies/mobius_strip"
require_relative "tasks"
require_relative "applications"

module SnailNetwork
  # Версия библиотеки.
  VERSION = "0.11.0"

  # Снаружи модуль и класс называются одинаково: SnailNetwork::SnailNetwork.
  # Network — то же самое базовое имя без этой коллизии.
  Network = ::SnailNetwork::SnailNetwork
end