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

    volume "grafana" {
      type            = "host"
      source          = "grafana"
    }

    vault {
      policies  = ["grafana"]
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

      template {
        source        = "local/provisioning/datasources/datasources.yaml.tpl"
        destination   = "local/provisioning/datasources/datasources.yaml"
      }

      template {
        # result of data template will be populated in this file
        destination = "secrets/vars.env"
        # all key/value pairs read will be exposed as environment variables to the frontend task
        env = true
        # read secret from Vault
        data = <<EOH
{{with secret "kv/grafana"}}
GF_SECURITY_ADMIN_USER={{.Data.data.admin_user | toJSON}}
GF_SECURITY_ADMIN_PASSWORD={{.Data.data.admin_pw | toJSON}}
{{end}}
EOH
      }

      volume_mount {
        volume      = "grafana"
        destination = "/etc/grafana"
        // read_only = true
      }

      config {
        image = "grafana/grafana:8.4.5"

        cap_drop = [
          "ALL",
        ]

        // volumes = [
        //   "grafana:/etc/grafana:ro",
        // ]

        ports = ["http"]
      }

      env {
        GF_ANALYTICS_REPORTING_ENABLED = "false"
        GF_PATHS_PROVISIONING = "/etc/grafana/provisioning/"
        GF_INSTALL_PLUGINS = "grafana-piechart-panel"
        GF_SERVER_ROOT_URL = "https://grafana.${var.domain}"
        GF_SECURITY_DISABLE_GRAVATAR = "true"
        GF_USERS_ALLOW_SIGN_UP = "false"
        GF_USERS_ALLOW_ORG_CREATE = "false"
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