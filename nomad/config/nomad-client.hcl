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
}

# this section was added manually
# we refer to just one vault server right now since using dns with consul currently is not working
# https://www.vaultproject.io/docs/configuration/service-registration/consul
# should be changed to `vault.service.consul` later on
vault {
  enabled = true
  address = "http://10.0.0.2:8200"
}