# Experiment — прогон сети на общем стимуле.

module SmLab
  class Experiment
    def self.run(network, steps:, input_type: :silence, homeostasis: true)
      raise ArgumentError, 'steps must be positive' unless steps.is_a?(Integer) && steps.positive?

      kind = input_type.to_sym
      case kind
      when :crawl
        unless network.respond_to?(:drive_at)
          raise ArgumentError, "#{network.class.name} does not define a crawl drive"
        end

        steps.times do |step|
          network.step!(external_input: network.drive_at(step), homeostasis: homeostasis)
        end
      when :rhythm
        unless network.respond_to?(:tonic_drive)
          raise ArgumentError, "#{network.class.name} does not define a tonic drive"
        end

        network.prepare_rhythm! if network.respond_to?(:prepare_rhythm!)
        steps.times do
          network.step!(external_input: network.tonic_drive, homeostasis: homeostasis)
        end
      else
        n = network.size
        steps.times do |step|
          network.step!(external_input: Stimuli.generate(kind, n, step), homeostasis: homeostasis)
        end
      end
      network
    end
  end
end
