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
# we refer to just one vault server right now since using dns with consul currently is not working
# https://www.vaultproject.io/docs/configuration/service-registration/consul
# should be changed to `vault.service.consul` later on
vault {
  enabled = true
  address = "http://127.0.0.1:8200"
  create_from_role = "nomad-cluster"
}
