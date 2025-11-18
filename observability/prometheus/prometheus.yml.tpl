# Prometheus Configuration for DavidShaevel.com Platform
# This configuration defines how Prometheus scrapes metrics from the platform services
#
# TEMPLATE VARIABLES (populated by Terraform):
#   - environment: Target environment (dev, staging, prod)
#   - service_prefix: Cloud Map service name prefix (e.g., dev-davidshaevel)
#   - platform_name: Platform identifier for external_labels (e.g., davidshaevel)
#   - private_dns_zone: Private hosted zone name (e.g., davidshaevel.local, dev.internal)

global:
  scrape_interval: 15s      # Scrape metrics every 15 seconds
  evaluation_interval: 15s  # Evaluate alerting rules every 15 seconds
  external_labels:
    environment: '${environment}'
    platform: '${platform_name}'

# Scrape configuration for all services
scrape_configs:
  # Backend API metrics (NestJS + prom-client)
  - job_name: 'backend'
    metrics_path: '/api/metrics'
    dns_sd_configs:
      - names:
          - '${service_prefix}-backend.${private_dns_zone}'
        type: 'SRV'
    relabel_configs:
      - source_labels: [job]
        target_label: service
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'nodejs_.*|backend_.*|process_.*|http_request.*|db_query.*'
        action: keep

  # Frontend application metrics (Next.js + prom-client)
  - job_name: 'frontend'
    metrics_path: '/api/metrics'
    dns_sd_configs:
      - names:
          - '${service_prefix}-frontend.${private_dns_zone}'
        type: 'SRV'
    relabel_configs:
      - source_labels: [job]
        target_label: service
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: 'nodejs_.*|frontend_.*|process_.*'
        action: keep

  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    relabel_configs:
      - source_labels: [job]
        target_label: service
    metric_relabel_configs:
      - source_labels: [__name__]
        regex: '^(up|prometheus_build_info|prometheus_config_.*|prometheus_engine_.*|prometheus_http_.*|prometheus_notifications_.*|prometheus_rule_.*|prometheus_target_.*|prometheus_tsdb_.*)$'
        action: keep
