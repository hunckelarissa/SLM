# test_applications.rb — Примеры должны делать то, что обещают.

require_relative './lib/sm_lab'
require 'minitest/autorun'

class TestApplications < Minitest::Test
  def test_gait_alternates
    report = SmLab::HalfCenter.demo
    assert report[:ok], report[:text]
    assert_operator report[:flips], :>=, 4
  end

  def test_phototaxis_reaches_the_light
    report = SmLab::BraitenbergVehicle.demo
    assert report[:ok], report[:text]
  end

  def test_worm_retreats_from_the_wall
    report = SmLab::Worm.demo
    assert report[:ok], report[:text]
    assert_equal 1, report[:turns]
    assert report[:weights_same]
    assert_operator report[:finish], :<, 0
    assert_operator report[:farthest], :<, report[:wall]
  end

  def test_sheet_turns_the_corner
    report = SmLab::Sheet.demo
    assert report[:ok], report[:text]
    assert_equal 1, report[:turns]
    assert_equal [[0, 0], [0, 1], [0, 2], [0, 3], [3, 3], [2, 3], [1, 3], [0, 3]], report[:peaks]
  end

  def test_echo_walks_the_chain
    report = SmLab::DelayLine.demo
    assert report[:ok], report[:text]
    assert_equal [0, 1, 2, 3, 4, 5, 6, 7], report[:peaks]
  end

  def test_habituation_fades_and_returns
    report = SmLab::Habituation.demo
    assert report[:ok], report[:text]
    assert_operator report[:first], :>, 0.9
    assert_operator report[:faded], :<, 0.25
    assert_operator report[:again], :>, 0.9
  end

  def test_watchdog_catches_a_spike
    report = SmLab::Watchdog.demo
    assert report[:ok], report[:text]
  end

  def test_rhythm_reader_separates_patterns
    report = SmLab::RhythmReader.demo
    assert report[:ok], report[:text]
    assert_operator report[:accuracy], :>=, 0.9
  end
end
