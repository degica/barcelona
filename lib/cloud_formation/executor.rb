module CloudFormation
  class UpdateInProgressException < Exception
    def initialize(msg="Applying stack template in progress")
      super
    end
  end

  class CannotUpdateRolledbackStackException < Exception
    def initialize(msg="Can't update creation-rollbacked stack")
      super
    end
  end

  class Executor
    attr_accessor :stack, :client

    def initialize(stack, district)
      @stack = stack
      @district = district
      @client = district.aws.cloudformation
      @s3_client = district.aws.s3
      @bucket = district.s3_bucket_name
    end

    def describe
      client.describe_stacks(stack_name: stack.name).stacks[0]
    rescue Aws::CloudFormation::Errors::ValidationError
      # when a stack doesn't exist
      nil
    end

    # Returns nil if a stack is not created
    def stack_status
      describe&.stack_status
    end

    def create(parameters: [])
      options = stack_options
      options = options.merge(parameters: parameters) if parameters.present?
      client.create_stack(options)
    end

    def update(change_set: false)
      if change_set
        create_change_set
      else
        client.update_stack(stack_options)
      end
    rescue Aws::CloudFormation::Errors::ValidationError => e
      if e.message == "No updates are to be performed."
        Rails.logger.warn "No updates are to be performed."
      else
        raise e
      end
    end

    def create_change_set(type: "UPDATE")
      dt = Time.current.strftime("%Y-%m-%d-%H%M%S")
      options = stack_options.merge({
                                      change_set_name: "changeset-#{dt}",
                                      change_set_type: type,
                                    })
      client.create_change_set(options)
    end

    def upload_to_s3!(template_name)
      params = {
        bucket: @bucket,
        key: template_name,
      }

      resp = @s3_client.put_object({
                                     body: stack.target!,
                                     **params
                                   })
      Rails.logger.info resp

      Rails.logger.info "Waiting for stack template to be uploaded"
      begin
        @s3_client.wait_until(:object_exists, params, 
                              before_wait: -> (attempts, response) do
                                Rails.logger.info "Waiting for stack template to be uploaded"
                              end
        )
      rescue Aws::Waiters::Errors::WaiterFailed => e
        Rails.logger.warn "Upload failed: #{e.message}"
        raise e
      end

      Rails.logger.info "Uploaded stack template to bucket"
    end

    def stack_options
      template_name = "stack_templates/#{stack.name}/#{Time.current.strftime("%Y-%m-%d-%H%M%S")}.template"
      upload_to_s3!(template_name)
      {
        stack_name: stack.name,
        capabilities: ["CAPABILITY_IAM"],
        template_url: "https://#{@bucket}.s3.amazonaws.com/#{template_name}"
      }
    end

    def create_or_update
      case stack_status
      when nil, "DELETE_COMPLETE" then
        create
      when "CREATE_COMPLETE", "UPDATE_COMPLETE", "UPDATE_ROLLBACK_COMPLETE"
        update
      when "ROLLBACK_COMPLETE"
        try_recreate
      else
        raise UpdateInProgressException
      end
    end

    def try_recreate
      puts 'Attempting to re-create stack from ROLLBACK_COMPLETE'
      delete

      loop do
        break if stack_status.nil? || stack_status == 'DELETE_COMPLETE'
        puts "Waiting for stack '#{stack.name}' to delete..."
        sleep 10
      end

      puts 'Stack deleted. Re-creating'
      create
    end

    def in_progress?
      status = stack_status
      return false if status.nil?

      !!(status =~ /_IN_PROGRESS/)
    end

    def stack_resources
      client.describe_stack_resources(stack_name: stack.name).stack_resources
    end

    # Returns CF ID => Real ID hash
    def resource_ids
      @resource_ids ||= stack_resources.map do |r|
        [r.logical_resource_id, r.physical_resource_id]
      end.to_h
    end

    def outputs
      if describe
        Hash[*describe.outputs.map{ |o| [o.output_key, o.output_value] }.flatten]
      end
    end

    def delete
      client.delete_stack(stack_name: stack.name) if stack_status
    end
  end
end
