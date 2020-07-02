class ReviewGroupPolicy < ApplicationPolicy
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

  def show?
    user.developer?
  end
end
