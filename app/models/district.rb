class District < ActiveRecord::Base
  extend Memoist

  before_create :create_ecs_cluster
  after_destroy :delete_ecs_cluster

  has_many :heritages, dependent: :destroy

  validates :name, presence: true
  validates :vpc_id, presence: true
  validates :private_hosted_zone_id, presence: true

  def to_param
    name
  end

  def subnets(network)
    Aws::EC2::Client.new.describe_subnets(
      filters: [
        {name: "vpc-id", values: [vpc_id]},
        {name: 'tag:Network', values: [network]}
      ]
    ).subnets
  end

  private

  def create_ecs_cluster
    ecs.create_cluster(cluster_name: name)
  end

  def delete_ecs_cluster
    ecs.delete_cluster(cluster: name)
  end

  def ecs
    Aws::ECS::Client.new
  end

  memoize :subnets, :ecs
end
