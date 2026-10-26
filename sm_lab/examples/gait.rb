#!/usr/bin/env ruby
# Два нейрона шагают в противофазе: спинальный генератор ритма.

require_relative '../lib/sm_lab'

report = SmLab::HalfCenter.demo(plot: true)
puts report[:text]
puts "  рисунок: #{report[:plot]}" if report[:plot]
exit(report[:ok] ? 0 : 1)
