class SetDefaultSslPolicy < ActiveRecord::Migration[5.0]
  def change
    # Do not need to update CF stacks because intermediate's ALB SSL policy
    # is same as the ALB's default
    Endpoint.update_all(ssl_policy: 'intermediate')
  end
end
