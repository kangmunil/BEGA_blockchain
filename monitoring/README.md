# BEGA L2 Monitoring Infrastructure

Complete monitoring stack for BEGA L2 blockchain infrastructure using Prometheus, Grafana, and Alertmanager.

## Overview

This monitoring infrastructure provides real-time metrics collection, visualization, and alerting for:
- L2 Execution Layer (op-geth)
- L2 Consensus/Rollup Layer (op-node)
- L2 Batcher (data availability posting)
- System health and performance metrics

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  l2-geth    │────▶│ Prometheus  │────▶│   Grafana   │
│  :6060      │     │   :9090     │     │    :3001    │
└─────────────┘     └─────────────┘     └─────────────┘
                            │
┌─────────────┐            │            ┌─────────────┐
│  l2-node    │────────────┤            │Alertmanager │
│  :7300      │            │            │    :9093    │
└─────────────┘            │            └─────────────┘
                           │
┌─────────────┐            │
│ l2-batcher  │────────────┘
│  :7301      │
└─────────────┘
```

## Access URLs

- **Prometheus**: http://localhost:9090
  - View raw metrics and targets
  - Query metrics using PromQL
  - Check alert rules status

- **Grafana**: http://localhost:3001
  - Username: `admin`
  - Password: `admin`
  - Visualize metrics with dashboards
  - Explore metrics interactively

- **Alertmanager**: http://localhost:9093
  - View active alerts
  - Configure notification receivers
  - Manage alert silencing

## Quick Start

### Start Monitoring Stack

```bash
# Start all monitoring services
docker compose up -d prometheus alertmanager grafana

# Check service status
docker compose ps | grep -E "(prometheus|alertmanager|grafana)"

# View Prometheus logs
docker compose logs -f prometheus

# View Grafana logs
docker compose logs -f grafana
```

### Verify Targets are UP

1. Open Prometheus: http://localhost:9090/targets
2. Check that all targets show status "UP":
   - l2-geth:6060
   - l2-node:7300
   - l2-batcher:7301
   - prometheus:9090

## Metrics Endpoints

### L2 Geth (Execution Layer)
- **Endpoint**: http://l2-geth:6060/debug/metrics/prometheus
- **Metrics**: Block height, transaction pool, gas usage, peer count, sync status

### L2 Node (Consensus/Rollup)
- **Endpoint**: http://l2-node:7300/metrics
- **Metrics**: L1/L2 sync status, derivation pipeline, sequencing metrics

### L2 Batcher
- **Endpoint**: http://l2-batcher:7301/metrics
- **Metrics**: Batch submission status, L1 transaction metrics, DA posting metrics

## Alert Rules

### Critical Alerts

1. **BatcherLowETH**
   - Triggers when batcher wallet has < 0.1 ETH
   - Severity: critical
   - Action: Refill batcher wallet immediately

2. **BatchSubmissionFailed**
   - Triggers when batcher fails to submit batches
   - Severity: critical
   - Action: Check L1 gas prices and batcher logs

3. **L2GethDown**
   - Triggers when L2 Geth is not responding
   - Severity: critical
   - Action: Restart l2-geth service

4. **L2NodeDown**
   - Triggers when L2 rollup node is down
   - Severity: critical
   - Action: Restart l2-node service

5. **BatcherDown**
   - Triggers when batcher service is down
   - Severity: critical
   - Action: Restart l2-batcher service

### Warning Alerts

1. **HighL1GasPrice**
   - Triggers when L1 gas > 50 gwei for 10 minutes
   - Severity: warning
   - Action: Monitor batch submission costs

2. **L2BlockProductionSlow**
   - Triggers when L2 block rate < 0.1 blocks/sec
   - Severity: warning
   - Action: Check sequencer performance

3. **LowPeerCount**
   - Triggers when L2 node has < 3 peers
   - Severity: warning
   - Action: Check network connectivity

## Configuration Files

### prometheus.yml
Defines scrape targets and intervals for metrics collection.

### alert_rules.yml
Defines alert conditions and thresholds for critical system events.

### alertmanager.yml
Configures notification receivers (Slack, Discord, email).

**To enable notifications:**
1. Edit `monitoring/alertmanager.yml`
2. Uncomment and configure webhook URLs for Slack or Discord
3. Restart alertmanager: `docker compose restart alertmanager`

## Creating Grafana Dashboards

### Using PromQL Queries

1. Open Grafana at http://localhost:3001
2. Login with admin/admin
3. Click "+" → "Dashboard" → "Add new panel"
4. Enter PromQL queries:

**Example Queries:**

```promql
# L2 block height
eth_block_number{job="l2-geth"}

# L2 transaction pool size
eth_txpool_pending{job="l2-geth"}

# Batcher batch submission rate
rate(batcher_batches_submitted_total[5m])

# L1 gas price
l1_gas_price_gwei

# L2 sync status
op_node_sync_status{job="l2-node"}
```

### Import Pre-built Dashboards

Community OP Stack dashboards (coming soon):
- Grafana Dashboard ID: TBD
- Import via Grafana UI → Dashboards → Import

## Troubleshooting

### Prometheus can't scrape targets

**Error**: Target shows "DOWN" status

**Solution**:
```bash
# Check if services are running with metrics enabled
docker compose ps | grep -E "(l2-geth|l2-node|l2-batcher)"

# Verify metrics endpoint is accessible
curl http://localhost:6060/debug/metrics/prometheus
curl http://localhost:7300/metrics
curl http://localhost:7301/metrics

# Restart services if needed
docker compose restart l2-geth l2-node l2-batcher
```

### Grafana can't connect to Prometheus

**Error**: "Failed to query data source"

**Solution**:
```bash
# Check Prometheus is running
docker compose ps prometheus

# Verify Prometheus API is accessible
curl http://localhost:9090/api/v1/targets

# Restart Grafana
docker compose restart grafana
```

### Alerts not firing

**Error**: No alerts showing in Alertmanager

**Solution**:
```bash
# Check alert rules are loaded
curl http://localhost:9090/api/v1/rules

# Verify Alertmanager configuration
docker compose logs alertmanager

# Test alert evaluation
curl 'http://localhost:9090/api/v1/query?query=ALERTS'
```

## Data Persistence

Metrics data is stored in:
- `./data/prometheus` - Time-series metrics (15 days retention)
- `./data/grafana` - Dashboards and settings
- `./data/alertmanager` - Alert state and silences

**To reset monitoring data:**
```bash
docker compose down prometheus grafana alertmanager
sudo rm -rf ./data/prometheus ./data/grafana ./data/alertmanager
docker compose up -d prometheus grafana alertmanager
```

## Security Notes

1. **Change Default Passwords**: Update Grafana admin password in production
2. **Network Security**: Consider restricting access to monitoring ports (9090, 9093, 3001)
3. **Webhook Secrets**: Use secure webhook URLs for alerting
4. **Data Retention**: Configure appropriate retention policies for metrics storage

## Next Steps

1. Create custom Grafana dashboards for BEGA L2 metrics
2. Configure Slack/Discord webhooks for critical alerts
3. Set up email notifications for warning alerts
4. Add custom alert rules for business-specific metrics
5. Implement log aggregation (ELK/Loki) for comprehensive observability

## References

- [Prometheus Documentation](https://prometheus.io/docs)
- [Grafana Documentation](https://grafana.com/docs)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager)
- [OP Stack Metrics](https://docs.optimism.io/builders/node-operators/management/metrics)
