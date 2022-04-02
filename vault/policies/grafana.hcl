path "kv/data/*" {
  capabilities = ["read"]
}

path "kv/data/grafana/*" {
  capabilities = ["create", "read", "update"]
}