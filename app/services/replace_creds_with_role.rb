class ReplaceCredsWithRole
  attr_accessor :district

  def initialize(district)
    @district = district
  end

  def run!
    ApplyDistrict.new(district).
      set_district_aws_credentials(district.aws_access_key_id,
                                   district.aws_secret_access_key,
                                   district.aws_session_token
                                  )
    district.save!
  end
end
