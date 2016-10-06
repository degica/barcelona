class OneoffSerializer < ActiveModel::Serializer
  attributes :id, :task_arn, :command, :status, :exit_code, :reason,
             :interactive_run_command, :container_instance_arn, :container_name

  belongs_to :heritage
  belongs_to :district
end
