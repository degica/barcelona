class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def create?
    user.allowed_to?(record.name.downcase, 'create')
  end

  def new?
    create?
  end

  def index?
    user.allowed_to?(record.name.downcase, 'index')
  end

  def method_missing(method_name, *args, &block)
    user.allowed_to?(record.class.name.downcase, method_name[0..-2])
  end

  def respond_to?(method_name, *args)
    return true if method_name.to_s.end_with?('?')

    false
  end

  def update?
    edit?
  end

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope
    end
  end
end
