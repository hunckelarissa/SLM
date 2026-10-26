# test_inhibition.rb — торможение в топологиях даёт противофазу и контраст.

require_relative './lib/sm_lab'
require 'minitest/autorun'

class TestInhibition < Minitest::Test
  ARCHITECTURES = [
    [SmLab::SnailHouse, 10],
    [SmLab::RingDance, 8],
    [SmLab::FlatGarden, 9],
    [SmLab::NestingDoll, 12],
    [SmLab::ChaoticBall, 10],
    [SmLab::Crystal, 27],
    [SmLab::Tentacles, 12],
    [SmLab::DoubleHelix, 10],
    [SmLab::PulsingCore, 16],
    [SmLab::Labyrinth, 10]
  ].freeze

  def test_every_architecture_inhibits
    ARCHITECTURES.each do |arch_class, count|
      net = arch_class.new(neuron_count: count)
      net.build_topology
      assert net.weights.flatten.any?(&:negative?), "#{arch_class.name} has no inhibitory weights"
    end
  end

  def test_chaotic_ball_keeps_dale_rows
    net = SmLab::ChaoticBall.new(neuron_count: 10)
    net.build_topology
    outgoing = net.weights[0].reject(&:zero?)
    assert outgoing.any?
    assert outgoing.all?(&:negative?)
  end

  def test_rhythm_stimulus_records_the_antiphase
    [
      [SmLab::RingDance, 8],
      [SmLab::DoubleHelix, 10],
      [SmLab::PulsingCore, 16],
      [SmLab::NestingDoll, 12]
    ].each do |arch, count|
      net = arch.new(neuron_count: count)
      SmLab::Experiment.run(net, steps: 80, input_type: :rhythm)
      frames = net.history.map { |frame| frame[:state].map { |neuron| neuron[:activation] } }
      high, low = net.rhythm_sides
      left = SmLab::Dynamics.mean_series(frames, high).drop(15)
      right = SmLab::Dynamics.mean_series(frames, low).drop(15)
      assert_operator SmLab::Dynamics.opposed_fraction(left, right), :>, 0.75, arch.name
      assert_operator SmLab::Dynamics.flips(left, right), :>=, 3, arch.name
    end
  end

  def test_antagonism_demo
    report = SmLab::Antagonism.demo
    assert report[:ok], report[:text]
    assert report[:rhythms].all? { |story| story[:flips] >= 3 }
    assert report[:crawls].all? { |story| story[:fraction] >= 0.9 }
  end
end
