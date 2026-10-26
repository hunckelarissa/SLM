# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SnailNetwork::Visualizer do
  it "рисует схему кольца в SVG без Graphviz" do
    network = SnailNetwork::Topologies::Ring.new(size: 6, settle_steps: 6, log: false)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "ring.svg")
      expect(described_class.new(logger: Logger.new(nil)).visualize(network, path)).to be true
      svg = File.read(path)

      expect(svg).to include("<svg")
      expect(svg.scan("<circle").size).to eq(6)
      expect(svg.scan("<polygon").size).to eq(network.synapses.size)
    end
  end

  it "сохраняет переворот знака красным ребром" do
    network = SnailNetwork::Topologies::MobiusStrip.new(log: false)
    svg = described_class.new(logger: Logger.new(nil)).render(network)

    expect(svg).to include('stroke="#d62728"')
  end

  it "разводит встречные рёбра по разные стороны" do
    network = SnailNetwork::Topologies::Star.new(log: false)
    svg = described_class.new(logger: Logger.new(nil)).render(network)
    controls = svg.scan(/Q [\d.]+ [\d.]+/)

    expect(controls.uniq.size).to eq(network.synapses.size)
  end

  it "подменяет расширение png на svg" do
    network = SnailNetwork::Topologies::Star.new(log: false)
    Dir.mktmpdir do |dir|
      asked = File.join(dir, "star.png")
      described_class.new(logger: Logger.new(nil)).visualize(network, asked)

      expect(File).to exist(File.join(dir, "star.svg"))
      expect(File).not_to exist(asked)
    end
  end
end
