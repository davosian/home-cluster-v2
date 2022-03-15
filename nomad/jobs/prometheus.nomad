job "prometheus" {
  datacenters = ["dc1"]
  type        = "service"

  group "monitoring" {
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
      size = 300
    }

    task "prometheus" {
      template {
        change_mode = "noop"
        destination = "local/webapp_alert.yml"
        data = <<EOH
---
groups:
- name: prometheus_alerts
  rules:
  - alert: Webapp down
    expr: absent(up{job="podinfo"})
    for: 10s
    labels:
      severity: critical
    annotations:
      description: "Our webapp is down."
EOH
      }

      template {
        change_mode = "noop"
        destination = "local/prometheus.yml"
        data = <<EOH
---
global:
  scrape_interval:     5s
  evaluation_interval: 5s

alerting:
  alertmanagers:
  - consul_sd_configs:
    - server: 'consul.service.consul:8500'
      services: ['alertmanager']

rule_files:
  - "webapp_alert.yml"

scrape_configs:

  - job_name: 'alertmanager'

    consul_sd_configs:
    - server: 'consul.service.consul:8500'
      services: ['alertmanager']

  - job_name: 'nomad_metrics'

    consul_sd_configs:
    - server: 'consul.service.consul:8500'
      services: ['nomad-client', 'nomad']

    relabel_configs:
    - source_labels: ['__meta_consul_tags']
      regex: '(.*)http(.*)'
      action: keep

    scrape_interval: 5s
    metrics_path: /v1/metrics
    params:
      format: ['prometheus']

  - job_name: 'podinfo'

    consul_sd_configs:
    - server: 'consul.service.consul:8500'
      services: ['podinfo']

    metrics_path: /metrics
EOH
      }

      driver = "docker"

      config {
        image = "prom/prometheus:latest"
        ports = ["prometheus_ui"]

        volumes = [
          "local/webapp_alert.yml:/etc/prometheus/webapp_alert.yml",
          "local/prometheus.yml:/etc/prometheus/prometheus.yml",
        ]


      }

      service {
        name = "prometheus"
        port = "prometheus_ui"

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.prometheus.rule=Host(`prometheus.davosian.rocks`)",
        ]

        check {
          name     = "prometheus_ui port alive"
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
