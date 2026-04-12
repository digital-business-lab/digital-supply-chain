# Operations & Backup

## Backup Strategy

Each lab island automatically backs up its data state via a shell script executed as a **systemd timer daily at 02:00**.

| What | How | Retention |
|---|---|---|
| Database dumps | `pg_dump` (PostgreSQL / ChirpStack), `mysqldump` (MariaDB / ERPNext) | 7 days |
| Docker volumes | `docker run --volumes-from` archive | 7 days |
| Configuration files | Included in the volume archive | 7 days |
| MikroTik router config | RouterOS export via scheduler | Weekly |

Backups are stored locally on each workstation. Optionally they can be synchronised to a shared network drive via `rsync`.

### Key Scripts (Farm Island — analogous for all islands)

| Script | Purpose |
|---|---|
| `scripts/backup.sh` | Full backup to timestamped archive under `~/farm-backups/` |
| `scripts/restore.sh` | Container stop → volume restore → DB restore → restart |
| `scripts/install-backup-timer.sh` | Installs systemd timer for daily 02:00 runs |
| `scripts/mikrotik-backup.rsc` | RouterOS backup commands (run on the MikroTik) |

### Quick Backup / Restore

```bash
# Manual backup
./farm-island/scripts/backup.sh

# Restore a specific backup
./farm-island/scripts/restore.sh ~/farm-backups/farm-backup-2026-03-22_02-00.tar.gz
```

## VM Templates for Teaching

In production, each island runs **natively on Ubuntu + Docker** — no hypervisor overhead, full RAM access, touchscreen kiosk works natively.

For teaching, a **VM-based approach on a separate lab server** runs in parallel:

| Step | Detail |
|---|---|
| Platform | KVM/QEMU with Virt-Manager; minimum 32 GB RAM for three island VMs simultaneously |
| Golden image | After the first complete island setup, take a VM snapshot and export as a base template |
| Practical operation | Start one template copy per student group — fully isolated, no mutual interference |
| Research operation | Run experiments (failure simulation, algorithm tests) in VM copies without affecting the production islands |

**Key distinction from backup:** A backup preserves the running operational state. A VM template freezes a defined *teaching state*. Students can break their island freely — restore takes minutes, not hours.

## Deployment (GitOps)

See [gitops.md](gitops.md) for the full GitOps workflow. Summary:

- All configuration lives in Git
- Each island runs a systemd timer that calls `deploy.sh` every 15 minutes
- `deploy.sh` does `git pull` + `docker compose up -d` — only changed services restart
- Rollback = `git revert` + push
