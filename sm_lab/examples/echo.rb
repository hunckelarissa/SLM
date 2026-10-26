#!/usr/bin/env ruby
# Импульс проходит по цепочке: где пик, столько шагов назад была вспышка.

require_relative '../lib/sm_lab'

report = SmLab::DelayLine.demo(plot: true)
puts report[:text]
puts "  рисунок: #{report[:plot]}" if report[:plot]
exit(report[:ok] ? 0 : 1)
