# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PointPaddingPolicy do
  subject(:policy) { described_class.new(user, :point_padding) }

  describe '#create?' do
    context 'with a signed-in user' do
      let(:user) { create(:user) }

      it { expect(policy.create?).to be(true) }
    end

    context 'with no user' do
      let(:user) { nil }

      it { expect(policy.create?).to be(false) }
    end
  end
end
