# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!
require 'webmock/rspec'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true
  config.include FactoryBot::Syntax::Methods
  config.include StubEnv::Helpers

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  config.before :all do |_example|
    Aws.config[:stub_responses] = true

    ENV['GITHUB_ORGANIZATION'] = 'degica'
    ENV['VAULT_URL'] ||= "http://my-vault.com"
    ENV['VAULT_PATH_PREFIX'] ||= "prefix"
  end

  config.before :each do
    stub_const("Gibberish::AES::SJCL::DEFAULTS", {
                 v:1, iter:1, ks:256, ts:96,
                 mode:"gcm", adata:"", cipher:"aes", max_iter: 1
               })
    allow_any_instance_of(Aws::CloudFormation::Client).to receive(:describe_stack_resources) {
      double(stack_resources: [
               double(logical_resource_id: "BastionServer",
                      physical_resource_id: "i-8c178e29"),
               double(logical_resource_id: "ContainerInstanceAccessibleSecurityGroup",
                      physical_resource_id: "sg-da330fbf"),
               double(logical_resource_id: "InboundNetworkAclEntryDmz0",
                      physical_resource_id: "barce-Inbou-15TQ2U2R0XKVX"),
               double(logical_resource_id: "InboundNetworkAclEntryDmz1",
                      physical_resource_id: "barce-Inbou-F3UWJW6PS2SL"),
               double(logical_resource_id: "InboundNetworkAclEntryDmz2",
                      physical_resource_id: "barce-Inbou-1783CJLI7NQSR"),
               double(logical_resource_id: "InboundNetworkAclEntryDmz3",
                      physical_resource_id: "barce-Inbou-5SOTBONOEHU1"),
               double(logical_resource_id: "InboundNetworkAclEntryDmz4",
                      physical_resource_id: "barce-Inbou-D5L4XMFKJP9O"),
               double(logical_resource_id: "InboundNetworkAclEntryDmz5",
                      physical_resource_id: "barce-Inbou-PG7I8E5UILEZ"),
               double(logical_resource_id: "InboundNetworkAclEntryDmzICMP",
                      physical_resource_id: "barce-Inbou-1MEGM2XROJIMJ"),
               double(logical_resource_id: "InboundNetworkAclEntryTrusted0",
                      physical_resource_id: "barce-Inbou-12KEUUTTPBZOZ"),
               double(logical_resource_id: "InboundNetworkAclEntryTrusted1",
                      physical_resource_id: "barce-Inbou-1A499PF4AG60Q"),
               double(logical_resource_id: "InboundNetworkAclEntryTrusted2",
                      physical_resource_id: "barce-Inbou-60RFA7R8DILK"),
               double(logical_resource_id: "InboundNetworkAclEntryTrusted3",
                      physical_resource_id: "barce-Inbou-14ZA18E2KFQRF"),
               double(logical_resource_id: "InboundNetworkAclEntryTrusted4",
                      physical_resource_id: "barce-Inbou-1HADFF504X2UR"),
               double(logical_resource_id: "InboundNetworkAclEntryTrusted5",
                      physical_resource_id: "barce-Inbou-HHDBYBD1D0E"),
               double(logical_resource_id: "InboundNetworkAclEntryTrustedICMP",
                      physical_resource_id: "barce-Inbou-1LM3O7A5EPPMT"),
               double(logical_resource_id: "InstanceSecurityGroup",
                      physical_resource_id: "sg-ef70528a"),
               double(logical_resource_id: "InstanceSecurityGroupSelfIngress",

                      physical_resource_id: "InstanceSecurityGroupSelfIngress"),
               double(logical_resource_id: "InternetGateway",
                      physical_resource_id: "igw-a770a2c2"),
               double(logical_resource_id: "LocalHostedZone",
                      physical_resource_id: "Z11CJJBJIUZTK8"),
               double(logical_resource_id: "NetworkAclDmz",
                      physical_resource_id: "acl-11bc2074"),
               double(logical_resource_id: "NetworkAclTrusted",
                      physical_resource_id: "acl-16bc2073"),
               double(logical_resource_id: "OutboundNetworkAclEntryDmz",
                      physical_resource_id: "barce-Outbo-GXTAJGIKOBWG"),
               double(logical_resource_id: "OutboundNetworkAclEntryTrusted",
                      physical_resource_id: "barce-Outbo-179UF8B16IDRE"),
               double(logical_resource_id: "PrivateELBSecurityGroup",
                      physical_resource_id: "sg-e6705283"),
               double(logical_resource_id: "PublicELBSecurityGroup",
                      physical_resource_id: "sg-e4705281"),
               double(logical_resource_id: "RouteDmz",
                      physical_resource_id: "barce-Route-HWYDOQX0HRDY"),
               double(logical_resource_id: "RouteTableDmz",
                      physical_resource_id: "rtb-78f1691d"),
               double(logical_resource_id: "RouteTableTrusted",
                      physical_resource_id: "rtb-79f1691c"),
               double(logical_resource_id: "SecurityGroupBastion",
                      physical_resource_id: "sg-ca0b3daf"),
               double(logical_resource_id: "SubnetDmz1",
                      physical_resource_id: "subnet-0fd4b078"),
               double(logical_resource_id: "SubnetDmz2",
                      physical_resource_id: "subnet-d84ef181"),
               double(logical_resource_id: "SubnetNetworkAclAssociationDmz1",
                      physical_resource_id: "aclassoc-8d6faee9"),
               double(logical_resource_id: "SubnetNetworkAclAssociationDmz2",
                      physical_resource_id: "aclassoc-8e6faeea"),
               double(logical_resource_id: "SubnetNetworkAclAssociationTrusted1",
                      physical_resource_id: "aclassoc-8f6faeeb"),
               double(logical_resource_id: "SubnetNetworkAclAssociationTrusted2",
                      physical_resource_id: "aclassoc-8c6faee8"),
               double(logical_resource_id: "SubnetRouteTableAssociationDmz1",
                      physical_resource_id: "rtbassoc-28bddf4d"),
               double(logical_resource_id: "SubnetRouteTableAssociationDmz2",
                      physical_resource_id: "rtbassoc-2bbddf4e"),
               double(logical_resource_id: "SubnetRouteTableAssociationTrusted1",
                      physical_resource_id: "rtbassoc-29bddf4c"),
               double(logical_resource_id: "SubnetRouteTableAssociationTrusted2",
                      physical_resource_id: "rtbassoc-2abddf4f"),
               double(logical_resource_id: "SubnetTrusted1",
                      physical_resource_id: "subnet-0ed4b079"),
               double(logical_resource_id: "SubnetTrusted2",
                      physical_resource_id: "subnet-d94ef180"),
               double(logical_resource_id: "VPC",
                      physical_resource_id: "vpc-87d855e2"),
               double(logical_resource_id: "VPCDHCPOptions",
                      physical_resource_id: "dopt-13f41f76"),
               double(logical_resource_id: "VPCDHCPOptionsAssociation",
                      physical_resource_id: "barce-VPCDH-QYVDCE2IOGZK"),
               double(logical_resource_id: "VPCGatewayAttachment",
                      physical_resource_id: "barce-VPCGa-1LOOQNJB1WRUG")
             ])
    }
  end
end
