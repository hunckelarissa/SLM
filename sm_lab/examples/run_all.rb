#!/usr/bin/env ruby
# Все прикладные примеры одним прогоном.

require_relative '../lib/sm_lab'

reports = [
  SmLab::HalfCenter.demo(plot: true),
  SmLab::BraitenbergVehicle.demo(plot: true),
  SmLab::DelayLine.demo(plot: true),
  SmLab::Worm.demo(plot: true),
  SmLab::Sheet.demo(plot: true),
  SmLab::Watchdog.demo(plot: true),
  SmLab::Habituation.demo(plot: true),
  SmLab::RhythmReader.demo(plot: true),
  SmLab::Antagonism.demo(plot: true)
]

puts reports.map { |report| report[:text] }.join("\n")
failed = reports.reject { |report| report[:ok] }
if failed.empty?
  puts "Примеры: #{reports.size}/#{reports.size} сошлись."
  exit 0
end

puts "Не сошлись: #{failed.map { |report| report[:title] }.join(', ')}"
exit 1
