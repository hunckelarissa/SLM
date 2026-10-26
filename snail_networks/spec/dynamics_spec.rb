# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe "Динамика улиток" do
  let(:configs) { SnailNetwork::NetworkBuilder.load_configs }

  it "отклоняет вектор входа неверной длины и нечисловые значения" do
    network = SnailNetwork::NetworkBuilder.build("ring", configs)
    expect { network.forward([1.0], record: false) }.to raise_error(ArgumentError, /входов/)
    expect { network.forward(["1", 0.0], record: false) }.to raise_error(ArgumentError, /число/)
  end

  it "не даёт выходу обогнать длину пути по решётке" do
    expect { SnailNetwork::Topologies::FlatSquare.new(settle_steps: 1, log: false) }
      .to raise_error(SnailNetwork::TopologyError, /settle_steps/)
  end

  it "сверяет input_size из конфигурации с реальными входами" do
    expect { SnailNetwork::Topologies::Ring.new(input_size: 4, settle_steps: 10, log: false) }
      .to raise_error(SnailNetwork::TopologyError, /input_size/)
  end

  it "отличает обход фиксированной длины от кратчайшего пути" do
    ring = SnailNetwork::Topologies::Ring.new(size: 6, settle_steps: 6, log: false)
    star = SnailNetwork::Topologies::Star.new(settle_steps: 4, log: false)

    expect(ring.reachable_in?(0, 0, 0)).to be true
    expect(ring.reachable_in?(0, 3, 3)).to be true
    expect(ring.reachable_in?(0, 1, 3)).to be false
    expect(star.reachable_in?(0, 1, 3)).to be true
    expect(star.reachable_in?(1, 2, 3)).to be false
    expect(star.reachable_in?(1, 2, 2)).to be true
    expect(ring.route_kind(0, 3, 3)).to eq(:wire)
    expect(ring.route_kind(0, 1, 3)).to eq(:none)
    expect(star.route_kind(0, 1, 3)).to eq(:bottleneck)
    expect(star.simple_path?(0, 1, 3)).to be false
    expect { ring.reachable_in?(0, 1, -1) }.to raise_error(ArgumentError, /шаг/)
  end

  it "находит на решётке простой обход мимо прямого ребра" do
    grid = SnailNetwork::Topologies::FlatSquare.new(log: false)

    expect(grid.distance_between(0, 1)).to eq(1)
    expect(grid.simple_path?(0, 1, 3)).to be true
    expect(grid.route_kind(0, 1, 3)).to eq(:detour)
  end

  it "считает хопы от входа до выхода" do
    flat = SnailNetwork::NetworkBuilder.build("flat_square", configs)
    ring = SnailNetwork::NetworkBuilder.build("ring", configs)
    expect(flat.hop_distance(12)).to eq(3)
    expect(ring.hop_distance(9)).to eq(8)
  end

  it "записывает номер такта и не смешивает прогоны" do
    network = SnailNetwork::NetworkBuilder.build("ring", configs)
    network.forward([0.0, 1.0], record: true)
    expect(network.activity_log.map(&:first)).to eq((0...network.config[:settle_steps]).to_a)
    network.forward([1.0, 0.0], record: true)
    expect(network.activity_log.size).to eq(network.config[:settle_steps])
  end

  it "использует смещение выходного нейрона" do
    network = SnailNetwork::Topologies::Layered.new(
      input_size: 2,
      hidden_size: 2,
      output_size: 1,
      settle_steps: 3,
      seed: 1,
      log: false
    )
    network.clear_parameters!
    network.neurons[network.output_indices.first].bias = 0.5
    value = network.forward([0.2, -0.3], record: false).first
    expect(value).to be_within(1e-9).of(Math.tanh(0.5))
  end

  it "воспроизводит хаотичный комок по seed" do
    edges = lambda do |seed|
      network = SnailNetwork::Topologies::ChaoticBlob.new(seed: seed, log: false)
      network.synapses.map { |synapse| [synapse.source.index, synapse.target.index, synapse.weight] }
    end
    expect(edges.call(5)).to eq(edges.call(5))
    expect(edges.call(5)).not_to eq(edges.call(6))
  end

  it "читает старый массив весов и отвергает чужую длину" do
    network = SnailNetwork::NetworkBuilder.build("ring", configs)
    entries = network.synapses.each_with_index.map do |synapse, index|
      {
        "index" => index,
        "source" => synapse.source.index,
        "target" => synapse.target.index,
        "weight" => 0.25,
        "flip_sign" => false
      }
    end

    Dir.mktmpdir do |dir|
      path = File.join(dir, "weights.json")
      File.write(path, JSON.generate(entries))
      network.load_weights(path)
      expect(network.synapses.map(&:weight)).to all(eq(0.25))

      File.write(path, JSON.generate(entries[0..-2]))
      expect { network.load_weights(path) }.to raise_error(ArgumentError, /синапс/)
    end
  end
end
