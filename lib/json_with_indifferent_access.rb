class JsonWithIndifferentAccess
  def self.load(str)
    loaded = JSON.load(str)
    loaded.is_a?(Hash) ? loaded.with_indifferent_access : loaded
  end

  def self.dump(obj)
    JSON.dump(obj)
  end
end
