---
apiVersion: 1

deleteDatasources:
  - name: prometheus
    orgId: 1

datasources:
  - name: prometheus
    type: prometheus
    access: proxy
    orgId: 1
    url: https://prometheus.{{ key "config/domain" }}
    user:
    password:
    database:
    basicAuth: false
    basicAuthUser:
    basicAuthPassword:
    isDefault: true
    jsonData:
      httpMethod: GET
    editable: true