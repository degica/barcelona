class ElasticIp < ActiveRecord::Base
  belongs_to :district

  before_validation :allocate

  validates :district, presence: true
  validates :allocation_id, presence: true

  def self.available(district)
    allocation_ids = district.aws.ec2.
                     describe_addresses(allocation_ids: self.pluck(:allocation_id)).
                     addresses.
                     select { |a| a.association_id.nil? }.
                     map(&:allocation_id)
    self.where(allocation_id: allocation_ids)
  end

  def allocate
    return if allocation_id.present?
    resp = ec2.allocate_address
    update!(allocation_id: resp.allocation_id)
  end

  def associate(ec2_instance_id)
    ec2.associate_address(
      instance_id: ec2_instance_id,
      allocation_id: allocation_id
    )
  end

  def ec2
    district.aws.ec2
  end
end
