variable "domain" {
  type = string
}

job "demo-webapp" {
  datacenters = ["dc1"]

  group "demo" {
    count = 2

    vault {
      policies  = ["demoapp"]
    }

    network {
      port  "http"{
        to = -1
      }
    }

    service {
      name = "demo-webapp"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.http.rule=Host(`webapp.${var.domain}`)",
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
        image = "hashicorp/demo-webapp-lb-guide"
        ports = ["http"]
      }

      template {
        data   = <<EOF
my secret: "{{ with secret "kv/data/demoapp" }}{{ .Data.data.greeting }}{{ end }}"
EOF
        destination = "local/demoapp.txt"
      }

      template {
        data   = <<EOF
my domain: {{key "config/domain"}}
EOF
        destination = "local/domain.txt"
      }
    }
  }
}
