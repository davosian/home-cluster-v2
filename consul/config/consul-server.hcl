# hashi-up consul install \
#   --ssh-target-addr $SERVER_1_IP \
#   --ssh-target-user $SSH_USER \
#   --ssh-target-key ~/.ssh/id_rsa \
#   --server \
#   --bind-addr '{{ GetPrivateInterfaces | include "network" "10.0.0.0/16" | attr "address" }}' \
#   --client-addr 0.0.0.0 \
#   --bootstrap-expect 3 \
#   --retry-join $SERVER_1_IP_INTERNAL --retry-join $SERVER_2_IP_INTERNAL --retry-join $SERVER_3_IP_INTERNAL

# generated with hashi-up

datacenter  = "dc1"
data_dir    = "/opt/consul"
bind_addr   = "{{ GetPrivateInterfaces | include \"network\" \"10.0.0.0/16\" | attr \"address\" }}"
client_addr = "0.0.0.0"
retry_join  = ["10.0.0.2", "10.0.0.3", "10.0.0.4"]
ports {
}
addresses {
}
ui               = true
server           = true
bootstrap_expect = 3