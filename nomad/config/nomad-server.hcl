# hashi-up nomad install \
#   --ssh-target-addr $SERVER_1_IP \
#   --ssh-target-user $SSH_USER \
#   --ssh-target-key ~/.ssh/id_rsa \
#   --server \
#   --advertise "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}" \
#   --bootstrap-expect 3

# generated with hashi-up

datacenter = "dc1"
data_dir   = "/opt/nomad"
advertise {
  http = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"
  rpc  = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"
  serf = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"
}
server {
  enabled          = true
  bootstrap_expect = 3
}

# this section was added manually
vault {
  enabled = true
  address = "http://active.vault.service.consul:8200"
  create_from_role = "nomad-cluster"
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}

consul {
  tags = ["controlplane"]
}
