#!/usr/bin/env ruby
# Касание стены гасит прямую волну и запускает обратную. Веса не меняются.

require_relative '../lib/sm_lab'

report = SmLab::Worm.demo(plot: true)
puts report[:text]
puts "  рисунок: #{report[:plot]}" if report[:plot]
exit(report[:ok] ? 0 : 1)
