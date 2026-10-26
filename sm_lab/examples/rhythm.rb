#!/usr/bin/env ruby
# Сеть только помнит ритм. Отличает рисунки линейный считыватель снаружи.

require_relative '../lib/sm_lab'

report = SmLab::RhythmReader.demo(plot: true)
puts report[:text]
puts "  рисунок: #{report[:plot]}" if report[:plot]
exit(report[:ok] ? 0 : 1)
