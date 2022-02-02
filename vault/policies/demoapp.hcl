path "kv/data/*" {
  capabilities = ["read"]
}

path "kv/data/demoapp/*" {
  capabilities = ["create", "read", "update"]
}