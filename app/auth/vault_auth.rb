class VaultAuth < Auth
  def enabled?
    ENV['VAULT_URL'].present?
  end

  def login
    authenticate
  end

  def authenticate
    res = lookup
    username = res.dig("data", "meta", "username")
    @current_user = User.find_or_create_by!(name: username) if username
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

  def vault_token
    request.headers['HTTP_X_VAULT_TOKEN']
  end

  def request_vault(req)
    req['X-Vault-Token'] = vault_token
    uri = URI(ENV['VAULT_URL'])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    res = http.request(req)
    raise ExceptionHandler::Forbidden.new("Your Vault token does not have a permission for #{req.path}") if res.code.to_i > 299

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
    req.body = {path: path}.to_json
    res = request_vault(req)
    res["capabilities"]
  end

  def lookup
    req = Net::HTTP::Get.new("/v1/auth/token/lookup-self")
    request_vault(req)
  end
end
