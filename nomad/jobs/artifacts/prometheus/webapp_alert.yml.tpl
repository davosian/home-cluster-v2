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