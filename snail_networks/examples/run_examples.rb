# frozen_string_literal: true

# Сценарии применения. Код выхода 0, только если каждый сценарий
# подтвердил своё свойство топологии.

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "snail_networks"

results = SnailNetwork::Applications.run_all

puts "=" * 70
puts "Улитки — примеры применения"
puts "=" * 70
results.each do |result|
  puts result.report
  [result.details[:grid], result.details[:table]].each do |extra|
    puts extra if extra.is_a?(String)
  end
end
puts "=" * 70

failed = results.reject(&:success)
if failed.empty?
  puts "Все #{results.size} сценариев сошлись."
  exit 0
end

puts "Не сошлись: #{failed.map(&:name).join(', ')}"
exit 1
