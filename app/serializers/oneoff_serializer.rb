class OneoffSerializer < ActiveModel::Serializer
  attributes :id, :task_arn, :status, :exit_code

  belongs_to :heritage
end
