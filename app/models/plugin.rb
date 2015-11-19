class Plugin < ActiveRecord::Base
  belongs_to :district

  serialize :plugin_attributes

  before_validation :default_attributes
  before_validation :name, uniqueness: {scope: :district_id}
  after_create :hook_created
  after_update :hook_updated
  after_save :save_district
  after_destroy :hook_destroyed

  def hook(trigger, origin, arg=nil)
    plugin.hook(trigger, origin, arg)
  end

  def to_param
    name
  end

  def plugin
    begin
      klass = ("Barcelona::Plugins::" + "#{name}_plugin".classify).constantize
    rescue NameError => e
      Rails.logger.error e
      return arg
    end
    klass.new(self)
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

  def save_district
    # trigger district callbacks so that AWS resources are properly updated
    district.save!
  end
end
