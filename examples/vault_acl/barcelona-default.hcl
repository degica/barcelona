path "secret/Barcelona/prefix/v1/user" {
  capabilities = ["update", "read"]
}

path "secret/Barcelona/prefix/v1/login" {
  capabilities = ["create"]
}

# oneoff API path is shallow. Need to give all users read access
# the API path will be changed in the future in order to have better permission control
path "secret/Barcelona/prefix/v1/oneoffs/*" {
  capabilities = ["read"]
}