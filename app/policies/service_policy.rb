class UserPolicy < ApplicationPolicy
  def scale?
    developer?
  end
end
