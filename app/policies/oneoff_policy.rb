class OneoffPolicy < ApplicationPolicy
  delegate :district, to: :record

  def show?
    developer?
  end

  def create?
    developer?
  end
end
