---
route:
  group_by: ["instance"]
  group_wait: 2m
  group_interval: 1h
  repeat_interval: 1d
  receiver: webhook

receivers:
  - name: webhook
    webhook_configs:
      # FIXME: Sorry, processing alerts is not part of this demo, hence the stub
      - url: http://invalid

inhibit_rules:
  - source_match:
      severity: "critical"
    target_match:
      severity: "warning"
    equal: ["alertname"]