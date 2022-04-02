# hashi-up nomad install \
#   --ssh-target-addr $CLIENT_1_IP \
#   --ssh-target-user $SSH_USER \
#   --ssh-target-key ~/.ssh/id_rsa \
#   --client \
#   --advertise "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"
# # manually add to the client section of /etc/nomad.d/nomad.hcl and restart the nomad service:
# # network_interface = "ens10"

# generated with hashi-up

datacenter = "dc1"
data_dir   = "/opt/nomad"
advertise {
  http = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"
  rpc  = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"
  serf = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"
}
client {
  enabled = true
  network_interface = "ens10"

  host_volume "grafana" {
    path = "/mnt/gluster-nomad/volumes/grafana"
  }
}

# this section was added manually
vault {
  enabled = true
  address = "http://active.vault.service.consul:8200"
}

telemetry {
  collection_interval = "1s"
  disable_hostname = true
  prometheus_metrics = true
  publish_allocation_metrics = true
  publish_node_metrics = true
}
