# Give full permission to the application
path "secret/Barcelona/prefix/v1/heritages/myapp*" {
  capabilities = ["create", "update", "read", "delete"]
}

# But do not allow to delete the application
path "secret/Barcelona/prefix/v1/heritages/myapp" {
  capabilities = ["create", "update", "read"]
}