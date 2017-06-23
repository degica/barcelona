# Give full permissions to the district
path "secret/Barcelona/prefix/v1/districts/my-district*" {
  capabilities = ["create", "update", "read", "delete"]
}