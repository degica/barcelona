class ImmutableValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    old_value = record.send("#{attribute}_was")

    if record.send("#{attribute}_changed?") && old_value.present? && !record.new_record?
      record.errors[attribute] << "is immutable"
    end
  end
end
