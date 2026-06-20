# Linux Systemd Service Troubleshooter

A read-only Bash toolkit for diagnosing failed, degraded, or slow `systemd` services.

## Features

- Service existence, active state, enablement, and unit-file location
- Full `systemctl status` capture
- Recent unit-specific journal events
- Dependency and reverse-dependency review
- Restart count, start-limit, and failure metadata
- Unit security exposure scoring where available
- Boot performance and critical-chain evidence
- Text and JSON outputs for support tickets

## Usage

```bash
chmod +x src/systemd_service_troubleshooter.sh
sudo ./src/systemd_service_troubleshooter.sh ssh.service
```

Optional output directory:

```bash
sudo ./src/systemd_service_troubleshooter.sh nginx.service --output /tmp/nginx-triage
```

## Safety

The script does not start, stop, restart, enable, disable, mask, or edit services. It only reads service and journal data.

## Validation

Test against an active unit, an intentionally failed lab unit, a missing unit, and a service with dependencies. Review logs for secrets before sharing.

## Professional value

Demonstrates Linux service troubleshooting, evidence-based escalation, dependency analysis, and safe operational practice.

## Author

Dewald Pretorius — L2 IT Support Engineer
