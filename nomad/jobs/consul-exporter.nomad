job "consul-exporter" {
  datacenters = ["dc1"]

  update {
    stagger      = "30s"
    max_parallel = 1
  }

  group "exporters" {
    count = 1

    network {
      port "consul_exporter" { 
        to = 9107
      }
    }

    task "consul-exporter" {
      driver = "docker"

      config {
        image = "prom/consul-exporter:latest"

        cap_drop = [
          "ALL",
        ]

        args = [
          "--consul.server",
          "consul.service.consul:8500",
        ]

        ports = ["consul_exporter"]
      }

      resources {
        cpu    = 100
        memory = 50
      }

      service {
        name = "${TASK}"
        
        tags = [
          "prometheus",
        ]
        
        port = "consul_exporter"

        check {
          type     = "http"
          path     = "/-/healthy"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}