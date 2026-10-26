# frozen_string_literal: true

require "yaml"
require_relative "snail_network"
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

module SnailNetwork
  # Фабрика для построения сетей по конфигурации.
  #
  # Позволяет:
  #   * загрузить все конфигурации из YAML-файла;
  #   * создать экземпляр нужной топологии по имени;
  #   * получить список доступных топологий.
  class NetworkBuilder
    DEFAULT_CONFIG_PATH = File.expand_path("../config/networks.yml", __dir__)

    # Реестр классов топологий (имя -> класс).
    TOPOLOGIES = {
      "FlatSquare" => Topologies::FlatSquare,
      "Ring" => Topologies::Ring,
      "Spiral" => Topologies::Spiral,
      "Cube" => Topologies::Cube,
      "ChaoticBlob" => Topologies::ChaoticBlob,
      "Layered" => Topologies::Layered,
      "NestedRings" => Topologies::NestedRings,
      "Sphere" => Topologies::Sphere,
      "Star" => Topologies::Star,
      "DoubleHelix" => Topologies::DoubleHelix,
      "Clover" => Topologies::Clover,
      "MobiusStrip" => Topologies::MobiusStrip
    }.freeze

    # Загрузить все конфигурации из YAML-файла.
    # @param path [String] путь к YAML-файлу
    # @return [Hash] имя сети -> хэш параметров
    def self.load_configs(path = DEFAULT_CONFIG_PATH)
      YAML.load_file(path)
    end

    # Создать сеть по имени конфигурации.
    # @param name [String, Symbol] имя сети (ключ в YAML)
    # @param configs [Hash, nil] загруженные конфигурации (если nil — загружаются из файла)
    # @return [SnailNetwork] экземпляр сети
    def self.build(name, configs = nil)
      configs ||= load_configs
      key = name.to_s
      raise ArgumentError, "Неизвестная конфигурация: #{key}" unless configs.key?(key)

      params = configs[key]
      klass = TOPOLOGIES.fetch(params["type"]) do
        raise ArgumentError, "Неизвестный тип топологии: #{params['type']}"
      end
      klass.new(params)
    end

    # Список имён доступных конфигураций.
    # @return [Array<String>]
    def self.names(configs = nil)
      (configs || load_configs).keys
    end
  end
end