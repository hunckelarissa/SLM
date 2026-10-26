#!/usr/bin/env ruby
# Плоский сад молчит на шуме датчика и загорается на выбросе.

require_relative '../lib/sm_lab'

report = SmLab::Watchdog.demo(plot: true)
puts report[:text]
puts "  рисунок: #{report[:plot]}" if report[:plot]
exit(report[:ok] ? 0 : 1)
