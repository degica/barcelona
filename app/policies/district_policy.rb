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

  def allocate_elastic_ip?
    user.developer?
  end
end
