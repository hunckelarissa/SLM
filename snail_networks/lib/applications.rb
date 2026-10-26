# frozen_string_literal: true

module SnailNetwork
  # Короткие прикладные сценарии. Каждый сценарий сам проверяет,
  # что топология сделала именно то, чего от неё ждут.
  module Applications
    Result = Struct.new(:name, :success, :summary, :details, keyword_init: true) do
      def report
        status = success ? "OK  " : "FAIL"
        "#{status}  #{name}: #{summary}"
      end
    end

    def self.all
      [
        XorGate, MobiusInversion, GridWave, StarConsensus, RingMemory,
        LearnedDelay, LearnedInversion, EchoRace,
        LearnedReturn, TanhDelay, EchoCensus, DetourEcho, RouteCensus,
        HeldXor, BottleneckCensus, TwinPulse, QuietTail,
        SignTable, RingBasin, TailStep
      ]
    end

    def self.run_all
      all.map(&:run)
    end
  end
end

require_relative "applications/xor_gate"
require_relative "applications/mobius_inversion"
require_relative "applications/grid_wave"
require_relative "applications/star_consensus"
require_relative "applications/ring_memory"
require_relative "applications/learned_delay"
require_relative "applications/learned_inversion"
require_relative "applications/echo_race"
require_relative "applications/learned_return"
require_relative "applications/tanh_delay"
require_relative "applications/echo_census"
require_relative "applications/detour_echo"
require_relative "applications/route_census"
require_relative "applications/held_xor"
require_relative "applications/bottleneck_census"
require_relative "applications/twin_pulse"
require_relative "applications/quiet_tail"
require_relative "applications/sign_table"
require_relative "applications/ring_basin"
require_relative "applications/tail_step"
