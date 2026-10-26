#!/usr/bin/env ruby
# Четыре нейрона ведут машину к свету: два глаза, два мотора.

require_relative '../lib/sm_lab'

report = SmLab::BraitenbergVehicle.demo(plot: true)
puts report[:text]
puts "  рисунок: #{report[:plot]}" if report[:plot]
exit(report[:ok] ? 0 : 1)
