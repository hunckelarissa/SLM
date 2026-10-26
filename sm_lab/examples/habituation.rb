#!/usr/bin/env ruby
# Один и тот же толчок сначала будит нейрон, потом нет. После паузы ответ возвращается.

require_relative '../lib/sm_lab'

report = SmLab::Habituation.demo(plot: true)
puts report[:text]
puts "  рисунок: #{report[:plot]}" if report[:plot]
exit(report[:ok] ? 0 : 1)
