class PluginPolicy < ApplicationPolicy
  delegate :district, to: :record

  def create?
    admin?
  end

  def index?
    developer?
  end

  def show?
    developer?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end
end
