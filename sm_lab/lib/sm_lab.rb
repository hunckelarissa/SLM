# sm_lab.rb — Точка входа в SMLab.
#
# «Мы не строим ИИ. Мы выращиваем цифровые организмы на дискете.»

module SmLab
  VERSION = '0.9.0'
end

require_relative 'neuron'
require_relative 'matrix'
require_relative 'network'
require_relative 'stimuli'
require_relative 'plot'
require_relative 'experiment'
require_relative 'readout'
require_relative 'dynamics'

Dir[File.join(__dir__, 'architectures', '*.rb')].sort.each { |path| require path }
Dir[File.join(__dir__, 'applications', '*.rb')].sort.each { |path| require path }
