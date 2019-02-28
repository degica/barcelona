class ReviewAppPolicy < ApplicationPolicy
  def create?
    user.developer?
  end

  def trigger?
    true
  end

  def destroy?
    user.developer?
  end

  def index?
    user.developer?
  end

  def show?
    user.developer?
  end
end
