module Vault
  class AuthResponse
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
end
