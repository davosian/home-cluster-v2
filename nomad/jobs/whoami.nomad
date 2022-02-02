job "whoami" {
  datacenters = ["dc1"]
  type        = "system"

  group "whoami" {
    network {
      port "http" {
        to = -1
      }
    }

    service {
      name = "whoami"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.whoami.rule=Host(`whoami.davosian.rocks`)",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "2s"
        timeout  = "2s"
      }
    }

    task "server" {
      env {
        PORT    = "${NOMAD_PORT_http}"
        NODE_IP = "${NOMAD_IP_http}"
      }

      driver = "docker"

      config {
        image = "jwilder/whoami:latest"
        ports = ["http"]
      }
    }
  }
}