job "traefik" {
  region      = "global"
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {
    network {
      port "http" {
        static = 8080
      }

      port "api" {
        static = 8081
      }
    }

    service {
      name = "traefik"

      check {
        name     = "alive"
        type     = "tcp"
        port     = "http"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:v2.5"
        network_mode = "host"

        volumes = [
          "local/traefik.toml:/etc/traefik/traefik.toml",
        ]
      }

      template {
        data = <<EOF
[entryPoints]
  [entryPoints.http]
  address = ":8080"
    [entryPoints.http.proxyProtocol]
    trustedIPs = ["127.0.0.1/32","10.0.0.0/24","172.26.0.0/16"] # Hetzner, ZeroTier
    
    [entryPoints.http.forwardedHeaders]
    trustedIPs = ["127.0.0.1/32","10.0.0.0/24","172.26.0.0/16"] # Hetzner, ZeroTier

  [entryPoints.traefik]
  address = ":8081"

  [entryPoints.metrics]
  address = ":8082"

[api]
    dashboard = true
    insecure  = true

[log]
  level = "INFO"

# Enable prometheus metrics
[metrics]
  [metrics.prometheus]
    entryPoint = "metrics"

# Enable Consul Catalog configuration backend.
[providers.consulCatalog]
  prefix           = "traefik"
  exposedByDefault = false

  [providers.consulCatalog.endpoint]
    address = "127.0.0.1:8500"
    scheme  = "http"

# Enable KV store in consul
[providers.consul]
  rootKey = "traefik"
  endpoints = ["127.0.0.1:8500"]
EOF

        destination = "local/traefik.toml"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
