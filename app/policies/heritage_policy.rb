class HeritagePolicy < ApplicationPolicy
  def method_missing(method_name, *args, &block)
    user.allowed_to?('heritage', method_name[0..-2], record.name)
  end
end
