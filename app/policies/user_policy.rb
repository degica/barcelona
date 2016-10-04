class UserPolicy < ApplicationPolicy
  def update?
    user == record
  end

  def destroy?
    user == record
  end

  def index?
    true
  end
end
