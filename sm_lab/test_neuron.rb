# test_neuron.rb — Тесты для Neuron

require_relative './lib/sm_lab'
require 'minitest/autorun'

class TestNeuron < Minitest::Test
  def setup
    @n = SmLab::Neuron.new(id: 0, threshold: 0.5)
  end

  def test_initial_state
    assert_equal 0, @n.activation
    assert_equal 0, @n.fatigue
    assert_equal :dormant, @n.state
    assert_equal 0, @n.id
  end

  def test_zero_input_stays_below_threshold
    @n.activate!(0.0)
    assert_operator @n.activation, :<, @n.threshold
    assert_equal :dormant, @n.state
  end

  def test_activate_small_input
    @n.activate!(0.1)
    assert_in_delta 0.2689, @n.activation, 0.002
    assert_operator @n.fatigue, :>, 0
    assert_equal :dormant, @n.state
  end

  def test_activate_large_input
    @n.activate!(5.0)
    assert_in_delta 0.9802, @n.activation, 0.002
    assert_operator @n.fatigue, :>, 0
    assert_equal :excited, @n.state
  end

  def test_activate_negative_input
    @n.activate!(-3.0)
    assert_operator @n.activation, :<, 0.1
    assert_equal :dormant, @n.state
  end

  def test_recover_reduces_fatigue
    @n.activate!(5.0)
    fat_before = @n.fatigue
    @n.recover(rate: 0.5)
    assert_operator @n.fatigue, :<, fat_before
  end

  def test_recover_does_not_erase_state
    @n.activate!(5.0)
    assert_equal :excited, @n.state
    @n.recover(rate: 0.5)
    assert_equal :excited, @n.state
  end

  def test_recover_to_zero
    @n.fatigue = 0.5
    40.times { @n.recover(rate: 0.1) }
    assert_in_delta 0.0, @n.fatigue, 0.01
  end

  def test_homeostatic_clamp_towards_target
    @n.activation = 0.1
    @n.homeostatic_clamp(target: 0.5)
    assert_operator @n.activation, :>, 0.1
    assert_operator @n.activation, :<=, 0.5
  end

  def test_homeostatic_clamp_above_target
    @n.activation = 0.9
    @n.homeostatic_clamp(target: 0.5)
    assert_operator @n.activation, :<, 0.9
    assert_operator @n.activation, :>=, 0.5
  end

  def test_to_h
    @n.activate!(1.0)
    snapshot = @n.to_h
    assert_equal 0, snapshot[:id]
    assert_kind_of Float, snapshot[:activation]
    assert_kind_of Float, snapshot[:fatigue]
    assert_includes %w[dormant active excited], snapshot[:state]
  end

  def test_inspect_returns_string
    assert_kind_of String, @n.inspect
    assert_includes @n.inspect, 'Neuron'
  end

  def test_chained_activation
    3.times { @n.activate!(2.0) }
    assert_operator @n.activation, :>, 0
    assert_operator @n.fatigue, :>, 0
  end
end
