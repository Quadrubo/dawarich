# frozen_string_literal: true

class PointPaddingPolicy < ApplicationPolicy
  def create?
    user.present?
  end
end
