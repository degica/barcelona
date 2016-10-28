class ReleasePolicy < ApplicationPolicy
  delegate :district, to: :record

  def show?
    developer?
  end

  def index?
    developer?
  end

  def rollback?
    developer?
  end
end
