# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SnailNetwork::Chart do
  it "рисует рост ряда вверх по странице SVG" do
    Dir.mktmpdir do |dir|
      path = described_class.line(
        [{ name: "a&b", values: [0.0, 1.0] }],
        File.join(dir, "line.svg"),
        title: "рост"
      )
      svg = File.read(path)
      points = svg[/points="([^"]+)"/, 1].split.map { |pair| pair.split(",").map(&:to_f) }

      expect(svg).to include("<svg")
      expect(points[1][1]).to be < points[0][1]
    end
  end

  it "экранирует подпись столбца" do
    Dir.mktmpdir do |dir|
      path = described_class.bars([{ label: "a&b", value: 0.5 }], File.join(dir, "bars.svg"), title: "сводка")
      svg = File.read(path)

      expect(svg).to include("a&amp;b")
      expect(svg).to include("<rect")
    end
  end

  it "отклоняет ряды разной длины и пустой набор столбцов" do
    expect { described_class.line([{ name: "a", values: [1] }, { name: "b", values: [1, 2] }], "x.svg") }
      .to raise_error(ArgumentError, /длины/)
    expect { described_class.bars([], "x.svg") }.to raise_error(ArgumentError, /столбц/)
  end

  it "сохраняет график активности каждого нейрона" do
    network = SnailNetwork::Topologies::Ring.new(size: 4, settle_steps: 3, log: false)
    expect(network.plot_activity("logs/unused.svg")).to be false

    network.forward([1.0, 0.0], record: true)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "activity.svg")
      expect(network.plot_activity(path, title: "кольцо")).to be true
      svg = File.read(path)
      expect(svg.scan("<polyline").size).to eq(network.neurons.size)
      expect(svg).to include("кольцо")
    end
  end
end
