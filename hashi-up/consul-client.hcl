# hashi-up consul install \
#   --ssh-target-addr $CLIENT_1_IP \
#   --ssh-target-user $SSH_USER \
#   --ssh-target-key ~/.ssh/id_rsa \
#   --bind-addr '{{ GetPrivateInterfaces | include "network" "10.0.0.0/16" | attr "address" }}' \
#   --retry-join $SERVER_1_IP_INTERNAL --retry-join $SERVER_2_IP_INTERNAL --retry-join $SERVER_3_IP_INTERNAL

# generated with hashi-up

datacenter = "dc1"
data_dir   = "/opt/consul"
bind_addr  = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"
retry_join = ["10.0.0.2", "10.0.0.3", "10.0.0.4"]
ports {
}
addresses {
}