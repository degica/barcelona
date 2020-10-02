class VaultAuth < Auth
  def self.vault_url
    ENV['VAULT_URL']
  end

  def self.enabled?
    vault_url.present?
  end

  def login
    req = Net::HTTP::Post.new("/v1/auth/github/login")
    req.body = { token: vault_token }.to_json

    http = Net::HTTP.new(vault_uri.host, vault_uri.port)
    res = http.request(req)

    if res.code != "200"
      raise ExceptionHandler::Unauthorized.new("You are not authorized to do that action")
    end

    auth_response = Vault::AuthResponse.new(res)
    if auth_response.username
      user = User.find_or_create_by!(name: auth_response.username)
      user.auth = 'vault'
      user.token = auth_response.client_token
      user.roles = auth_response.policies
      user.save
      user
    end
  end

  def authenticate
    @current_user = User.find_by_token(vault_token)
  end

  # Ignore resource based authorization
  def authorize_resource(*args)
  end

  def authorize_action
    if !cap_probe.authorized?(request.path, request.method)
      raise ExceptionHandler::Forbidden.new("You are not authorized to do that action")
    end
  end

  private

  def vault_uri
    URI(VaultAuth.vault_url)
  end

  def vault_path_prefix
    ENV['VAULT_PATH_PREFIX']
  end

  def vault_token
    request.headers['HTTP_X_VAULT_TOKEN']
  end

  def cap_probe
    @cap_probe ||= Vault::CapProbe.new(vault_uri, vault_token, vault_path_prefix)
  end
end
