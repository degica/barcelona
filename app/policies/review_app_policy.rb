class ReviewAppPolicy < ApplicationPolicy
  def ci_create?
    true
  end

  def ci_delete?
    true
  end
end
