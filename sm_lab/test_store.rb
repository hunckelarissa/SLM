# test_store.rb — Журнал прогонов пишет и читает один файл.

require 'tmpdir'
require_relative './lib/sm_lab'
require_relative './lib/store'
require 'minitest/autorun'

class TestStore < Minitest::Test
  def test_round_trip_of_latest_run
    path = File.join(Dir.tmpdir, "smlab-#{Process.pid}.db")
    FileUtils.rm_f(path)
    store = SmLab::Store.new(path)
    net = SmLab::RingDance.new(neuron_count: 3)
    SmLab::Experiment.run(net, steps: 4, input_type: :silence)
    store.record_run(name: net.name, neuron_count: net.size, input_type: :silence, frames: net.history)

    rows = store.latest_summaries
    assert_equal 1, rows.size
    assert_equal 'RingDance', rows[0][1]
    assert_equal 3, rows[0][2]
    series = store.series(rows[0][0])
    assert_equal 4, series.size
    assert_in_delta series.last[1], net.mean_activation, 0.001
  ensure
    FileUtils.rm_f(path)
  end
end
