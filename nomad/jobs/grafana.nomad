variable "domain" {
  type = string
}

job "grafana" {
  datacenters = ["dc1"]

  update {
    stagger      = "30s"
    max_parallel = 1
  }

  group "grafana" {
    count = 1

    ephemeral_disk {
      size    = 300
      migrate = true
    }

    restart {
      attempts = 3
      interval = "2m"
      delay    = "15s"
      mode     = "fail"
    }

    network {
      port "http" { 
        to = 3000
      }
    }

    task "grafana" {
      driver = "docker"

      artifact {
        # Double slash required to download just the specified subdirectory, see:
        # https://github.com/hashicorp/go-getter#subdirectories
        source = "git::https://github.com/davosian/home-cluster-v2.git//nomad/jobs/artifacts/grafana"
      }

      artifact {
        source = "https://raw.githubusercontent.com/davosian/home-cluster-v2/main/nomad/jobs/templates/grafana/datasources/datasources.yaml.tpl"
      }

      template {
        source        = "local/datasources.yaml.tpl"
        destination   = "local/provisioning/datasources/datasources.yaml"
      }

      // dynamic "template" {
      //   for_each = fileset(".", "{config,users}.d/*.yml")

      //   content {
      //     data        = file(template.value)
      //     destination = "local/${template.value}"
      //     change_mode = "noop"
      //   }
      // }

      config {
        image = "grafana/grafana:8.4.4"

        cap_drop = [
          "ALL",
        ]

        volumes = [
          "local:/etc/grafana:ro",
        ]

        ports = ["http"]
      }

      env {
        GF_INSTALL_PLUGINS           = "grafana-piechart-panel"
        GF_SERVER_ROOT_URL           = "https://grafana.${var.domain}"
        GF_SECURITY_ADMIN_PASSWORD   = "admin"
        GF_SECURITY_DISABLE_GRAVATAR = "true"
      }

      resources {
        cpu    = 100
        memory = 50
      }

      service {
        name = "grafana"
        tags = [
          "http",
          "traefik.enable=true",
          "traefik.http.routers.grafana.rule=Host(`grafana.${var.domain}`)",
        ]
        port = "http"

        check {
          type     = "http"
          path     = "/api/health"
          interval = "10s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}