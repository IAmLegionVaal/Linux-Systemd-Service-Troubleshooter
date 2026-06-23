# Linux Systemd Service Troubleshooter

A Linux support toolkit for diagnosing and repairing failed, degraded or incorrectly configured systemd services.

## Diagnostic script

```bash
chmod +x src/systemd_service_troubleshooter.sh
sudo ./src/systemd_service_troubleshooter.sh ssh.service
```

The diagnostic script captures service state, unit files, journal events, dependencies, restart metadata and boot-performance evidence.

## Repair script

Preview the default repair:

```bash
chmod +x src/systemd_service_repair.sh
sudo ./src/systemd_service_repair.sh ssh.service --dry-run
```

Reload unit files, clear the failed state, restart and verify a service:

```bash
sudo ./src/systemd_service_repair.sh ssh.service
```

Run one explicit action:

```bash
sudo ./src/systemd_service_repair.sh nginx.service --action reload
sudo ./src/systemd_service_repair.sh nginx.service --action enable
sudo ./src/systemd_service_repair.sh nginx.service --action reset-failed
```

## What the repair does

- Validates that the selected unit exists.
- Supports start, restart, reload, enable, disable and reset-failed actions.
- The default repair reloads systemd, clears failure state and restarts the selected unit.
- Captures service state and recent journal events before and after repair.
- Verifies that the unit is active when the selected action should leave it running.
- Supports confirmation prompts, dry-run, logs and clear exit codes.

## Safety and limitations

Disabling a service also stops it and requires confirmation. A unit with invalid configuration, missing dependencies or an application-level failure can still require vendor-specific repair.

## Maintainer

IAmLegionVaal
