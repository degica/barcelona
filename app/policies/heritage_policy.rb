class HeritagePolicy < ApplicationPolicy
  delegate :district, to: :record

  def index?
    developer?
  end

  def show?
    developer?
  end

  def create?
    developer?
  end

  def update?
    developer?
  end

  def destroy?
    developer?
  end

  def trigger?
    true
  end

  def set_env_vars
    developer?
  end

  def delete_env_vars
    developer?
  end
end
