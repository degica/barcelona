class DistrictPolicy < ApplicationPolicy
  def create?
    true
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  def index?
    developer?
  end

  def apply_stack?
    admin?
  end

  def sign_public_key?
    admin?
  end

  def district
    record
  end
end
