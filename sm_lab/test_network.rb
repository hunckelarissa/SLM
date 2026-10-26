# test_network.rb — Тесты для Network и всех архитектур

require_relative './lib/sm_lab'
require 'minitest/autorun'

class ProbeNet < SmLab::Network
  def build_topology
    @weights = [
      [0.0, 0.0],
      [6.0, 0.0]
    ]
  end
end

class TestNetwork < Minitest::Test
  def test_base_class_raises_build_topology
    net = SmLab::Network.new(name: 'Base', neuron_count: 4)
    assert_raises(NotImplementedError) { net.build_topology }
  end

  def test_rejects_empty_network
    assert_raises(ArgumentError) { SmLab::Network.new(name: 'Base', neuron_count: 0) }
  end

  def test_info_reports_means_not_sums
    net = SmLab::SnailHouse.new(neuron_count: 4)
    net.neurons.each { |neuron| neuron.activation = 0.25 }
    info = net.info
    assert_in_delta 0.25, info[:avg_activation], 0.0001
    assert_in_delta 0.0, info[:avg_fatigue], 0.0001
  end

  def test_network_info
    net = SmLab::SnailHouse.new(neuron_count: 5)
    net.step!
    info = net.info
    assert_equal 'SnailHouse', info[:name]
    assert_equal 5, info[:neurons]
    assert_kind_of Integer, info[:weights_nonzero]
    assert_operator info[:weights_nonzero], :>, 0
    assert_equal 1, info[:step_count]
    assert_in_delta net.mean_activation, info[:avg_activation], 0.0001
  end

  def test_step_propagates_previous_activation
    net = ProbeNet.new(name: 'Probe', neuron_count: 2, homeostasis_rate: 0.0)
    net.build_topology
    net.neurons[0].activation = 1.0
    net.neurons[1].activation = 0.0
    net.step!(external_input: [0.0, 0.0], homeostasis: false)
    assert_operator net.neurons[1].activation, :>, 0.95
    assert_operator net.neurons[0].activation, :<, 0.4
  end

  def test_step_rejects_short_input
    net = SmLab::RingDance.new(neuron_count: 4)
    error = assert_raises(ArgumentError) { net.step!(external_input: [0.2, 0.2]) }
    assert_match(/does not match 4 neurons/, error.message)
  end

  def test_step_rejects_non_numeric_input
    net = SmLab::RingDance.new(neuron_count: 2)
    error = assert_raises(ArgumentError) { net.step!(external_input: ['нет', 'числа']) }
    assert_match(/numeric/, error.message)
  end

  def test_step_works
    net = SmLab::SnailHouse.new(neuron_count: 5)
    net.step!
    assert_operator net.step_count, :>=, 1
    assert net.neurons.none? { |neuron| neuron.activation.negative? }
    assert net.neurons.none? { |neuron| neuron.activation > 1.01 }
  end

  def test_multiple_steps
    net = SmLab::RingDance.new(neuron_count: 6)
    10.times { net.step! }
    assert_equal 10, net.step_count
    assert net.neurons.any? { |neuron| neuron.activation.positive? }
  end

  def test_external_input
    net = SmLab::FlatGarden.new(neuron_count: 4)
    input = [0.5] * net.size
    net.step!(external_input: input)
    assert_operator net.step_count, :>=, 1
  end

  def test_rounded_grid_accepts_its_own_size
    net = SmLab::FlatGarden.new(neuron_count: 7)
    assert_equal 9, net.size
    net.step!(external_input: [0.2] * net.size)
    assert_equal 1, net.step_count
  end

  def test_inspect_state
    net = SmLab::ChaoticBall.new(neuron_count: 6)
    net.step!
    state = net.inspect_state
    assert_kind_of Array, state
    assert_equal 6, state.size
    state.each do |neuron|
      assert_kind_of Integer, neuron[:id]
      assert_kind_of Float, neuron[:activation]
      assert_kind_of Float, neuron[:fatigue]
    end
  end

  def test_history_is_public
    net = SmLab::RingDance.new(neuron_count: 3)
    2.times { net.step! }
    assert_equal 2, net.history.size
    assert_equal 1, net.history.first[:step]
  end

  def test_inspect_string
    net = SmLab::SnailHouse.new(neuron_count: 5)
    inspected = net.inspect
    assert_kind_of String, inspected
    assert_includes inspected, 'SnailHouse'
  end

  def test_homoeostasis_reduces_deviation
    net = SmLab::SnailHouse.new(neuron_count: 4, homeostasis_rate: 0.2)
    net.neurons[0].activation = 1.0
    net.neurons[1].activation = 1.0
    net.neurons[2].activation = 1.0
    net.neurons[3].activation = 0.0
    before = net.neurons.map { |neuron| (neuron.activation - 0.5).abs }.max
    net.apply_homeostasis
    after = net.neurons.map { |neuron| (neuron.activation - 0.5).abs }.max
    assert_operator after, :<, before
  end

  def test_local_rng_does_not_leak
    srand(123)
    SmLab::ChaoticBall.new(neuron_count: 8).build_topology
    SmLab::Labyrinth.new(neuron_count: 8).build_topology
    after = 3.times.map { rand }
    srand(123)
    expected = 3.times.map { rand }
    assert_equal expected, after
  end

  def test_chaotic_ball_is_deterministic_and_square
    left = SmLab::ChaoticBall.new(neuron_count: 6)
    right = SmLab::ChaoticBall.new(neuron_count: 6)
    left.build_topology
    right.build_topology
    assert_equal left.weights, right.weights

    tiny = SmLab::ChaoticBall.new(neuron_count: 1)
    tiny.build_topology
    assert_equal [1, 1], [tiny.weights.size, tiny.weights.first.size]
    tiny.step!
  end

  def test_tentacles_smaller_than_old_core
    net = SmLab::Tentacles.new(neuron_count: 2)
    net.build_topology
    net.step!(external_input: [0.2, 0.2])
    assert_equal 1, net.core_size
    assert_equal 2, net.size
  end

  def test_crystal_rounds_up_without_crashing
    net = SmLab::Crystal.new(neuron_count: 20)
    assert_equal 27, net.size
    net.step!(external_input: [0.1] * net.size)
  end

  def test_stimuli_are_repeatable
    left = SmLab::Stimuli.generate(:random, 5, 3)
    right = SmLab::Stimuli.generate(:random, 5, 3)
    assert_equal left, right
    assert_equal 5, left.size
  end
end

class TestArchitectures < Minitest::Test
  ARCHITECTURES = [
    [SmLab::SnailHouse, 10],
    [SmLab::RingDance, 8],
    [SmLab::FlatGarden, 9],
    [SmLab::NestingDoll, 12],
    [SmLab::ChaoticBall, 10],
    [SmLab::Crystal, 8],
    [SmLab::Tentacles, 10],
    [SmLab::DoubleHelix, 10],
    [SmLab::PulsingCore, 12],
    [SmLab::Labyrinth, 10]
  ].freeze

  ARCHITECTURES.each do |arch_class, default_count|
    define_method("test_#{arch_class.name.downcase}") do
      net = arch_class.new(neuron_count: default_count)
      assert_operator net.neurons.size, :>, 0, "#{arch_class.name} has no neurons"
      net.build_topology
      assert_kind_of Array, net.weights, "#{arch_class.name} weights must be array"
      assert_operator net.weights.size, :>, 0
      net.weights.each do |row|
        assert_kind_of Array, row
        assert_equal net.size, row.size
      end
      refute_nil net.layout
      assert_equal net.size, net.layout.size
    end
  end

  ARCHITECTURES.each do |arch_class, default_count|
    define_method("test_#{arch_class.name.downcase}_step") do
      net = arch_class.new(neuron_count: default_count)
      5.times { net.step!(external_input: Array.new(net.size, 0.2)) }
      assert_operator net.step_count, :>=, 5
    end
  end
end
