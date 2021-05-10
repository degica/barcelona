class DistrictPolicy < ApplicationPolicy
  def create?
    user.admin?
  end

  def update?
    user.admin?
  end

  def destroy?
    user.admin?
  end

  def index?
    user.developer?
  end

  def launch_instances?
    user.developer?
  end

  def terminate_instance?
    user.developer?
  end

  def apply_stack?
    user.admin?
  end

  def sign_public_key?
    user.admin?
  end
end
