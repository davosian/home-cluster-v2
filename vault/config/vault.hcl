# hashi-up vault install \
#     --ssh-target-addr $SERVER_1_IP \
#     --ssh-target-user $SSH_USER \
#     --ssh-target-key ~/.ssh/id_rsa \
#     --storage consul \
#     --api-addr http://$SERVER_1_IP_INTERNAL:8200

# generated with hashi-up

ui = true
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
api_addr = "http://10.0.0.2:8200"
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true

  # manually added
  telemetry {
    unauthenticated_metrics_access = true
  }
}

# manually added
service_registration "consul" {
  service_tags = "http,controlplane"
}

telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}