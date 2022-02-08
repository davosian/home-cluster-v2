variable "domain" {
  type = string
}

job "podinfo" {
  datacenters = ["dc1"]

  group "podinfo" {
    count = 2

    network {
      port  "podinfo-ui" {
        to = 9898
      }
    }

    service {
      name = "podinfo"
      port = "podinfo-ui"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.podinfo.rule=Host(`${var.domain}`) && PathPrefix(`/podinfo/`)", # make sure to add the trailing slash when calling the URL
        "traefik.http.routers.podinfo.middlewares=podinfo_stripprefix",
        "traefik.http.middlewares.podinfo_stripprefix.stripprefix.prefixes=/podinfo/",
        "traefik.http.middlewares.podinfo_stripprefix.stripprefix.forceSlash=false",
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "2s"
        timeout  = "2s"
      }
    }

    task "podinfo" {
      
      driver = "docker"

      config {
        image = "stefanprodan/podinfo"
        ports = ["podinfo-ui"]
      }
    }
  }
}
