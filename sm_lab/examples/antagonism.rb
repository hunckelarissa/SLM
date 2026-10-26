#!/usr/bin/env ruby
# Противофаза в самих архитектурах: кольцо, спираль, ядро, щупальца, тропа.

require_relative '../lib/sm_lab'

report = SmLab::Antagonism.demo(plot: true)
puts report[:text]
puts "  рисунок: #{report[:plot]}" if report[:plot]
exit(report[:ok] ? 0 : 1)
