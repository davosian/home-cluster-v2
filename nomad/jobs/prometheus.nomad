variable "domain" {
  type = string
}

job "prometheus" {
  datacenters = ["dc1"]
  
  update {
    stagger      = "30s"
    max_parallel = 1
  }

  group "prometheus" {
    count = 1

    network {
      port "prometheus_ui" {
        to = 9090
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay    = "15s"
      mode     = "fail"
    }

    ephemeral_disk {
      size    = 600
      migrate = true
    }

    task "prometheus" {
      driver = "docker"

      artifact {
        # Double slash required to download just the specified subdirectory, see:
        # https://github.com/hashicorp/go-getter#subdirectories
        source = "git::https://github.com/davosian/home-cluster-v2.git//nomad/jobs/artifacts/prometheus"
      }

      config {
        image = "prom/prometheus:latest"
        ports = ["prometheus_ui"]

        cap_drop = [
          "ALL",
        ]

        volumes = [
          "local/webapp_alert.yml:/etc/prometheus/webapp_alert.yml:ro",
          "local/prometheus.yml:/etc/prometheus/prometheus.yml:ro",
        ]
      }

      resources {
        cpu    = 100
        memory = 100
      }

      service {
        name = "prometheus"
        port = "prometheus_ui"

        tags = [
          "http",

          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.${var.domain}`)",

          // See: https://docs.traefik.io/routing/services/
          "traefik.http.services.prometheus.loadbalancer.sticky=true",
          "traefik.http.services.prometheus.loadbalancer.sticky.cookie.httponly=true",
          // "traefik.http.services.prometheus.loadbalancer.sticky.cookie.secure=true",
          "traefik.http.services.prometheus.loadbalancer.sticky.cookie.samesite=strict",
        ]

        check {
          name     = "prometheus_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }

      template {
        source        = "local/prometheus.yml.tpl"
        destination   = "local/prometheus.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
      
      template {
        source        = "local/webapp_alert.yml.tpl"
        destination   = "local/webapp_alert.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}
