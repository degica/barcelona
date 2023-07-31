module DisplayHelper
  def format_value(value)
    if value.is_a?(Array) || value.is_a?(Hash)
      return value.to_yaml.sub(/---\n?/, '')
    end
    value.inspect
  end
end
