class Plugin < ActiveRecord::Base
  belongs_to :district

  serialize :plugin_attributes

  before_validation :default_attributes
  before_validation :name, uniqueness: {scope: :district_id}
  after_create :hook_created
  after_create :hook_updated
  after_destroy :hook_destroyed

  def hook(trigger, origin, arg=nil)
    begin
      klass = ("Barcelona::Plugins::" + "#{name}_plugin".classify).constantize
    rescue NameError => e
      Rails.logger.error e
      return arg
    end
    klass.new(self).hook(trigger, origin, arg)
  end

  def to_param
    name
  end

  private

  def default_attributes
    self.plugin_attributes ||= {}
  end

  def hook_created
    hook(:created, self)
  end

  def hook_updated
    hook(:updated, self)
  end

  def hook_destroyed
    hook(:destroyed, self)
  end
end
