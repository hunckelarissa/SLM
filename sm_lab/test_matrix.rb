# test_matrix.rb — Тесты SimpleMatrix

require_relative './lib/sm_lab'
require 'minitest/autorun'

class TestSimpleMatrix < Minitest::Test
  def test_dot_uses_every_column
    matrix = SmLab::SimpleMatrix.rows([[1.0, 2.0], [0.0, 4.0]])
    assert_equal [5.0, 8.0], matrix.dot([1.0, 2.0])
  end

  def test_rejects_ragged_rows
    assert_raises(ArgumentError) { SmLab::SimpleMatrix.rows([[1, 2], [3]]) }
  end

  def test_count_nonzero
    matrix = SmLab::SimpleMatrix.rows([[0, 1], [0, 0]])
    assert_equal 1, matrix.count_nonzero
  end
end
