# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Snail Networks топологии" do
  let(:configs) { SnailNetwork::NetworkBuilder.load_configs }

  # Общие проверки для каждой топологии.
  shared_examples "корректная топология" do |name|
    let(:network) { SnailNetwork::NetworkBuilder.build(name, configs) }

    it "создаёт нейроны и синапсы" do
      expect(network.neurons).not_to be_empty
      expect(network.synapses).not_to be_empty
    end

    it "все нейроны имеют уникальные индексы" do
      indices = network.neurons.map(&:index)
      expect(indices.uniq.size).to eq(indices.size)
    end

    it "входные и выходные индексы в пределах диапазона нейронов" do
      max_index = network.neurons.map(&:index).max
      expect(network.input_indices).to all(be_between(0, max_index))
      expect(network.output_indices).to all(be_between(0, max_index))
    end

    it "forward возвращает вектор нужной длины" do
      input = Array.new(network.input_indices.size) { 0.5 }
      output = network.forward(input, record: false)
      expect(output.size).to eq(network.output_indices.size)
      expect(output).to all(be_a(Numeric))
    end

    it "синапсы корректно связывают source и target" do
      network.synapses.each do |synapse|
        expect(synapse.source.outgoing).to include(synapse)
        expect(synapse.target.incoming).to include(synapse)
      end
    end

    it "сохраняет и загружает веса" do
      Dir.mktmpdir do |dir|
        weights_file = File.join(dir, "#{name}_weights.json")
        network.save_weights(weights_file)
        saved = network.weights.dup

        network.set_weights(Array.new(network.weights.size) { 0.0 })
        expect(network.weights).not_to eq(saved)

        network.load_weights(weights_file)
        expect(network.weights).to eq(saved)
      end
    end
  end

  describe "FlatSquare" do
    it_behaves_like "корректная топология", "flat_square"

    it "имеет 16 нейронов" do
      net = SnailNetwork::NetworkBuilder.build("flat_square", configs)
      expect(net.neurons.size).to eq(16)
    end

    it "угловые нейроны имеют 2 связи, краевые — 3, внутренние — 4" do
      net = SnailNetwork::NetworkBuilder.build("flat_square", configs)
      # Угол (0,0) = индекс 0.
      expect(net.neurons[0].outgoing.size).to eq(2)
      # Внутренний (1,1) = индекс 5.
      expect(net.neurons[5].outgoing.size).to eq(4)
    end
  end

  describe "Ring" do
    it_behaves_like "корректная топология", "ring"

    it "имеет 10 нейронов и 10 однонаправленных связей" do
      net = SnailNetwork::NetworkBuilder.build("ring", configs)
      expect(net.neurons.size).to eq(10)
      expect(net.synapses.size).to eq(10)
    end

    it "связи образуют замкнутое кольцо 0→1→…→9→0" do
      net = SnailNetwork::NetworkBuilder.build("ring", configs)
      net.synapses.each_with_index do |synapse, i|
        expect(synapse.source.index).to eq(i)
        expect(synapse.target.index).to eq((i + 1) % 10)
      end
    end
  end

  describe "Spiral" do
    it_behaves_like "корректная топология", "spiral"

    it "имеет 12 нейронов" do
      net = SnailNetwork::NetworkBuilder.build("spiral", configs)
      expect(net.neurons.size).to eq(12)
    end

    it "имеет последовательные связи и перемычки между витками" do
      net = SnailNetwork::NetworkBuilder.build("spiral", configs)
      # Последовательные: 0→1, 1→2, ..., 10→11.
      (0..10).each do |i|
        expect(net.synapses.any? { |s| s.source.index == i && s.target.index == i + 1 }).to be true
      end
      # Перемычки: 0→4, 1→5, ...
      expect(net.synapses.any? { |s| s.source.index == 0 && s.target.index == 4 }).to be true
    end
  end

  describe "Cube" do
    it_behaves_like "корректная топология", "cube"

    it "имеет 8 нейронов" do
      net = SnailNetwork::NetworkBuilder.build("cube", configs)
      expect(net.neurons.size).to eq(8)
    end

    it "каждая вершина имеет 3 двунаправленных связи (степень 3)" do
      net = SnailNetwork::NetworkBuilder.build("cube", configs)
      net.neurons.each do |neuron|
        expect(neuron.outgoing.size).to eq(3)
        expect(neuron.incoming.size).to eq(3)
      end
    end
  end

  describe "ChaoticBlob" do
    it_behaves_like "корректная топология", "chaotic_blob"

    it "имеет 20 нейронов" do
      net = SnailNetwork::NetworkBuilder.build("chaotic_blob", configs)
      expect(net.neurons.size).to eq(20)
    end

    it "каждый нейрон имеет 3–4 входа" do
      net = SnailNetwork::NetworkBuilder.build("chaotic_blob", configs)
      net.neurons.each do |neuron|
        expect(neuron.incoming.size).to be_between(3, 4)
      end
    end
  end

  describe "Layered" do
    it_behaves_like "корректная топология", "layered"

    it "имеет 11 нейронов (3+6+2)" do
      net = SnailNetwork::NetworkBuilder.build("layered", configs)
      expect(net.neurons.size).to eq(11)
    end

    it "не имеет обратных связей (ациклическая)" do
      net = SnailNetwork::NetworkBuilder.build("layered", configs)
      net.synapses.each do |synapse|
        expect(synapse.source.index).to be < synapse.target.index
      end
    end

    it "снижает ошибку биполярного XOR стохастическим градиентом" do
      net = SnailNetwork::Applications::XorGate.build(seed: 1)
      inputs = SnailNetwork::Applications::XorGate::INPUTS
      targets = SnailNetwork::Applications::XorGate::TARGETS
      before = net.mean_squared_error(inputs, targets)
      stats = net.train(inputs, targets, epochs: 80)
      expect(stats[:final_mse]).to be < before
      expect(stats[:final_mse]).to be < 1.0
    end
  end

  describe "NestedRings" do
    it_behaves_like "корректная топология", "nested_rings"

    it "имеет 18 нейронов (3 кольца × 6)" do
      net = SnailNetwork::NetworkBuilder.build("nested_rings", configs)
      expect(net.neurons.size).to eq(18)
    end

    it "имеет кольцевые и радиальные связи" do
      net = SnailNetwork::NetworkBuilder.build("nested_rings", configs)
      # Кольцевая связь внутри первого кольца: 0→1.
      expect(net.synapses.any? { |s| s.source.index == 0 && s.target.index == 1 }).to be true
      # Радиальная связь между кольцами: 0↔6.
      expect(net.synapses.any? { |s| s.source.index == 0 && s.target.index == 6 }).to be true
      expect(net.synapses.any? { |s| s.source.index == 6 && s.target.index == 0 }).to be true
    end
  end

  describe "Sphere" do
    it_behaves_like "корректная топология", "sphere"

    it "имеет 12 нейронов" do
      net = SnailNetwork::NetworkBuilder.build("sphere", configs)
      expect(net.neurons.size).to eq(12)
    end

    it "каждый нейрон имеет степень 5 (5 соседей)" do
      net = SnailNetwork::NetworkBuilder.build("sphere", configs)
      net.neurons.each do |neuron|
        expect(neuron.outgoing.size).to eq(5)
      end
    end
  end

  describe "Star" do
    it_behaves_like "корректная топология", "star"

    it "имеет 9 нейронов (1 центр + 8 периферийных)" do
      net = SnailNetwork::NetworkBuilder.build("star", configs)
      expect(net.neurons.size).to eq(9)
    end

    it "центральный нейрон связан со всеми периферийными" do
      net = SnailNetwork::NetworkBuilder.build("star", configs)
      expect(net.neurons[0].outgoing.size).to eq(8)
      expect(net.neurons[0].incoming.size).to eq(8)
    end

    it "периферийные нейроны не связаны между собой" do
      net = SnailNetwork::NetworkBuilder.build("star", configs)
      (1..8).each do |i|
        expect(net.neurons[i].outgoing.size).to eq(1)
        expect(net.neurons[i].outgoing.first.target.index).to eq(0)
      end
    end
  end

  describe "DoubleHelix" do
    it_behaves_like "корректная топология", "double_helix"

    it "имеет 14 нейронов (2 спирали × 7)" do
      net = SnailNetwork::NetworkBuilder.build("double_helix", configs)
      expect(net.neurons.size).to eq(14)
    end

    it "имеет последовательные связи внутри спиралей и перемычки между ними" do
      net = SnailNetwork::NetworkBuilder.build("double_helix", configs)
      # Последовательная связь в первой спирали: 0→1.
      expect(net.synapses.any? { |s| s.source.index == 0 && s.target.index == 1 }).to be true
      # Перемычка между спиралями: 0↔7.
      expect(net.synapses.any? { |s| s.source.index == 0 && s.target.index == 7 }).to be true
    end
  end

  describe "Clover" do
    it_behaves_like "корректная топология", "clover"

    it "имеет 9 нейронов (3 ядра + 3×2 лепестка)" do
      net = SnailNetwork::NetworkBuilder.build("clover", configs)
      expect(net.neurons.size).to eq(9)
    end

    it "ядро (0,1,2) является общим для всех колец и не дублируется" do
      net = SnailNetwork::NetworkBuilder.build("clover", configs)
      expect(net.synapses.any? { |s| s.source.index == 0 && s.target.index == 3 }).to be true
      expect(net.synapses.any? { |s| s.source.index == 4 && s.target.index == 1 }).to be true
      pairs = net.synapses.map { |synapse| [synapse.source.index, synapse.target.index] }
      expect(pairs.count { |pair| pair == [1, 2] }).to eq(1)
      expect(pairs.uniq.size).to eq(pairs.size)
    end

    it "снимает выход с лепестков, а не с зажатого ядра" do
      net = SnailNetwork::NetworkBuilder.build("clover", configs)
      expect(net.output_indices).to eq([4, 6, 8])
      expect(net.input_indices & net.output_indices).to be_empty
    end
  end

  describe "MobiusStrip" do
    it_behaves_like "корректная топология", "mobius_strip"

    it "имеет 12 нейронов" do
      net = SnailNetwork::NetworkBuilder.build("mobius_strip", configs)
      expect(net.neurons.size).to eq(12)
    end

    it "связь 11→0 имеет переворот знака (flip_sign)" do
      net = SnailNetwork::NetworkBuilder.build("mobius_strip", configs)
      flip_synapse = net.synapses.find { |s| s.source.index == 11 && s.target.index == 0 }
      expect(flip_synapse).not_to be_nil
      expect(flip_synapse.flip_sign).to be true
    end

    it "остальные связи не имеют переворота знака" do
      net = SnailNetwork::NetworkBuilder.build("mobius_strip", configs)
      net.synapses.reject { |s| s.source.index == 11 }.each do |synapse|
        expect(synapse.flip_sign).to be false
      end
    end
  end

  describe "NetworkBuilder" do
    it "загружает все 12 конфигураций" do
      expect(configs.size).to eq(12)
    end

    it "создаёт сеть по имени" do
      net = SnailNetwork::NetworkBuilder.build(:ring, configs)
      expect(net).to be_a(SnailNetwork::Topologies::Ring)
    end

    it "выбрасывает ошибку для неизвестной конфигурации" do
      expect { SnailNetwork::NetworkBuilder.build(:unknown, configs) }
        .to raise_error(ArgumentError)
    end
  end
end