# frozen_string_literal: true

require "spec_helper"

RSpec.describe SnailNetwork::Applications do
  described_class.all.each do |application|
    it "подтверждает сценарий #{application.name.split('::').last}" do
      result = application.run
      expect(result.success).to be(true), result.summary
    end
  end
end
