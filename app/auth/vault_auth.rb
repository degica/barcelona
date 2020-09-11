class VaultAuthResponse
  def initialize(resp)
    @resp = resp
  end

  def username
    data.dig('auth', 'metadata', 'username')
  end

  def org
    data.dig('auth', 'metadata', 'org')
  end

  def policies
    data.dig('auth', 'policies')
  end

  def client_token
    data.dig('auth', 'client_token')
  end

  private

  def data
    JSON.parse @resp.body
  end
end

class VaultAuth < Auth
  def self.enabled?
    ENV['VAULT_URL'].present?
  end

  def login
    req = Net::HTTP::Post.new("/v1/auth/github/login")
    req.body = {token: vault_token}.to_json

    http = Net::HTTP.new(vault_uri.host, vault_uri.port)
    res = http.request(req)

    if res.code != "200"
      raise ExceptionHandler::Forbidden.new("You are not authorized to do that action")
    end

    auth_response = VaultAuthResponse.new(res)
    if auth_response.username
      user = User.find_or_create_by!(name: auth_response.username)
      user.auth = 'vault'
      user.token = auth_response.client_token
      user.roles = auth_response.policies
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
    capabilities = get_capabilities

    authorized = case request.method
                 when "POST"
                   capabilities.include? "create"
                 when "PATCH", "PUT"
                   capabilities.include? "update"
                 when "GET"
                   capabilities.include? "read"
                 when "DELETE"
                   capabilities.include? "delete"
                 else
                   raise ExceptionHandler::Unauthorized.new("HTTP method not supported")
                 end

    unless authorized || capabilities.include?("root")
      raise ExceptionHandler::Forbidden.new("You are not authorized to do that action")
    end
  end

  private

  def vault_uri
    URI(ENV['VAULT_URL'])
  end

  def vault_token
    request.headers['HTTP_X_VAULT_TOKEN']
  end

  def request_vault(req)
    req['X-Vault-Token'] = vault_token
    http = Net::HTTP.new(vault_uri.host, vault_uri.port)
    http.use_ssl = true if vault_uri.scheme == 'https'
    res = http.request(req)

    if res.code.to_i > 299
      Rails.logger.error "ERROR: Vault returned code #{res.code} and #{res.body.inspect}"
      raise ExceptionHandler::Forbidden.new("Your Vault token does not have a permission for #{req.path}")
    end

    JSON.load(res.body)
  end

  def get_capabilities
    prefix = if ENV['VAULT_PATH_PREFIX']
               '/' + ENV['VAULT_PATH_PREFIX']
             else
               ''
             end
    path = "secret/Barcelona#{prefix}#{request.path}"

    req = Net::HTTP::Post.new("/v1/sys/capabilities-self")
    req.body = {paths: [path]}.to_json
    res = request_vault(req)

    res["capabilities"]
  end
end
