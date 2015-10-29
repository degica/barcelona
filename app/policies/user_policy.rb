class UserPolicy < ApplicationPolicy
  def update?
    user.admin? || user == record
  end

  def destroy?
    user.admin?
  end

  def index?
    true
  end
end
