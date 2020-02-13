class DistrictPolicy < ApplicationPolicy
  def create?
    user.admin?
  end

  def method_missing(method_name, *args, &block)
    user.allowed_to?('district', method_name[0..-2], record.name)
  end
end
