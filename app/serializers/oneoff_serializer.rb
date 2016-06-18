class OneoffSerializer < ActiveModel::Serializer
  attributes :id, :task_arn, :command, :status, :exit_code, :reason

  belongs_to :app
end
