variable "domain" {
  type = string
}

job "alertmanager" {
  datacenters = ["dc1"]

  update {
    stagger      = "30s"
    max_parallel = 1
  }

  group "alertmanager" {
    count = 1

    network {
      port "alertmanager_ui" {
        to = 9093
      }
    }

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }

    ephemeral_disk {
      size = 300
    }

    task "alertmanager" {
      driver = "docker"

      artifact {
        # Double slash required to download just the specified subdirectory, see:
        # https://github.com/hashicorp/go-getter#subdirectories
        source = "git::https://github.com/davosian/home-cluster-v2.git//nomad/jobs/artifacts/alertmanager"
      }
      
      config {
        image = "prom/alertmanager:latest"
        ports = ["alertmanager_ui"]

        cap_drop = [
          "ALL",
        ]

        volumes = [
          "secret/alertmanager.yml:/etc/alertmanager/config.yml",
        ]
      }

      resources {
        cpu    = 100
        memory = 50
      }
      
      service {
        name = "alertmanager"

        tags = [
          "http",
          "prometheus",

          "traefik.enable=true",
          "traefik.http.routers.alertmanager.rule=Host(`alertmanager.${var.domain}`)",

          // See: https://docs.traefik.io/routing/services/
          "traefik.http.services.alertmanager.loadbalancer.sticky=true",
          "traefik.http.services.alertmanager.loadbalancer.sticky.cookie.httponly=true",
          // "traefik.http.services.alertmanager.loadbalancer.sticky.cookie.secure=true",
          "traefik.http.services.alertmanager.loadbalancer.sticky.cookie.samesite=strict",
        ]

        port = "alertmanager_ui"
        
        check {
          name     = "alertmanager_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }

      template {
        source        = "local/alertmanager.yml.tpl"
        destination   = "secret/alertmanager.yml"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}

