# GitOps Workflow

All configuration, compose files, and scripts are versioned in this repository. Each island pulls changes independently from the remote — no central push, no SSH access required from the development machine.

## What Lives in Git

| Included | Excluded |
|---|---|
| `docker-compose.yml` and all config files | `.env` files (passwords — stored locally, never committed) |
| Deployment, backup, and bootstrap scripts | Docker volumes / database data |
| All documentation (`*.md`, HTML overviews) | Backup archives (`*.tar.gz`, `*.sql.gz`) |

## Deploying a Change

```bash
# 1. Make and commit the change on the development machine
git add farm-island/config/mosquitto/mosquitto.conf
git commit -m "Increase Mosquitto max connections to 100"
git push

# 2. On the island — runs automatically every 15 min, or trigger manually:
sudo systemctl start farm-deploy.service
```

The `deploy.sh` script does:
1. `git pull` — fetch latest commits
2. `docker compose up -d` — only changed services restart (Docker Compose diffing)
3. Log the result to `/var/log/scm-lab/farm-island-deploy.log`

## Setting Up Auto-Deploy (Once Per Island)

```bash
# Run once after bootstrap
sudo ./farm-island/scripts/install-deploy-timer.sh
```

This installs `farm-deploy.service` and `farm-deploy.timer` as systemd units. The timer fires every 15 minutes.

## Viewing Logs

```bash
sudo systemctl start farm-deploy.service     # trigger immediately
journalctl -u farm-deploy.service -f         # follow live output
cat /var/log/scm-lab/farm-island-deploy.log  # full deploy log
```

## Rollback

```bash
# On the development machine
git revert <commit-hash>
git push
# Island picks it up within 15 min (or trigger manually)
```

## GitHub Actions

A GitHub Action (`.github/workflows/docs.yml`) automatically builds the MkDocs documentation site and deploys it to GitHub Pages on every push to `main`. No manual build step required.

See the [workflow file](../.github/workflows/docs.yml) for details.
