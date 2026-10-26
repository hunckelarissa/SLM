#!/usr/bin/env ruby
# Горб идёт по ряду тора и на краю сворачивает в столбец.

require_relative '../lib/sm_lab'

report = SmLab::Sheet.demo(plot: true)
puts report[:text]
puts "  рисунок: #{report[:plot]}" if report[:plot]
exit(report[:ok] ? 0 : 1)
