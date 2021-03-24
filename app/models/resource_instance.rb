class ResourceInstance < ApplicationRecord
  belongs_to :resource_class
  belongs_to :district
  has_many :resource_instance_items

  validates :name, presence: true
  validates :name, uniqueness: true
  validates :resource_class, presence: true
  validates :district, presence: true

  validate :validate_items

  private

  def current_items_hash
    make_hashes!
    @current_items_hash
  end

  def required_items_hash
    make_hashes!
    @required_items_hash
  end

  def optional_items_hash
    make_hashes!
    @optional_items_hash
  end

  def make_hashes!
    return unless @current_items_hash.nil?

    @current_items_hash = {}

    resource_instance_items.each do |item|
      @current_items_hash[item.name] = item
    end

    @current_items_hash

    @required_items_hash = {}
    @optional_items_hash = {}
    return if resource_class.nil?

    resource_class.resource_class_items.each do |item|
      if item.optional?
        @optional_items_hash[item.name] = item
      else
        @required_items_hash[item.name] = item
      end
    end
  end

  def unspecified_requires
    required_items_hash.keys - current_items_hash.keys
  end

  def extra_items
    (optional_items_hash.keys + required_items_hash.keys) - current_items_hash.keys
  end

  def validate_items
    if !unspecified_requires.empty?
      errors.add(:resource_instance_items, "#{unspecified_requires.join(',')} are required fields but not specified")
    end

    if !extra_items.empty?
      errors.add(:resource_instance_items, "#{extra_items.join(',')} are not fields on #{resource_class.name}")
    end
  end
end
