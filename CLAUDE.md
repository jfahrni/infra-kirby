# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Infrastructure-as-Code for hosting Kirby CMS sites in Docker behind a Traefik reverse proxy. **No application code belongs here.** The actual Kirby installations live in separate git repos cloned into `SITE/www/` on the server (gitignored).

| Concern | Repo | Owner |
|---|---|---|
| Docker / Apache config | this repo (`infra-kirby`) | Server-Admin |
| Traefik / SSL / routing | separate infra repo | Server-Admin |
| pfadiheim-buelach.ch site | `site-pfadiheim` | Entwickler Pfadiheim |
| fahrni.ch site | `site-fahrni` | Entwickler Fahrni |

## Repo structure

```
infra-kirby/
├── CLAUDE.md
├── apache/
│   ├── Dockerfile                   ← shared base image for all Kirby sites
│   └── apache.conf                  ← Apache VirtualHost config
├── pfadiheim-buelach/
│   ├── docker-compose.yml
│   └── www/                         ← Kirby site repo (separate git repo, gitignored)
└── fahrni/
    ├── docker-compose.yml
    └── www/                         ← Kirby site repo (separate git repo, gitignored)
```

## Architecture

```
Internet → Traefik (external repo) → [fahrni-web, pfadiheim-web] containers
```

- All containers join external Docker network `traefik`; each site also has an isolated internal network (`fahrni-internal`, `pfadiheim-internal`)
- Traefik routing is configured entirely via labels in each site's `docker-compose.yml` — no Traefik config belongs in this repo
- Containers serve only HTTP on port 80; TLS is terminated by Traefik

**Shared base image** (`apache/`): `php:8.3-apache` with `gd` (JPEG, WebP, AVIF, FreeType), `zip`, `opcache`; security headers, gzip, and static asset caching configured in `apache.conf`.

**Kirby public-folder layout** — DocumentRoot is `/var/www/site/public`. Only `public/` is web-accessible; `content/`, `site/`, `storage/`, `kirby/`, `vendor/` sit outside DocumentRoot.

## Configuration details

### Base image (`apache/`)

- Base: `php:8.3-apache`
- PHP extensions: `gd`, `zip` (Kirby requirements)
- Apache: `mod_rewrite` enabled, `AllowOverride All` for `.htaccess`
- Upload limits: `upload_max_filesize=32M`, `post_max_size=32M`

### Networks

| Network | Type | Used by |
|---|---|---|
| `traefik` | external, bridge | managed by Traefik; all web containers attach to it |
| `pfadiheim-internal` | internal | pfadiheim-buelach container only |
| `fahrni-internal` | internal | fahrni container only |

## Key commands

### Rebuild image and restart (after Dockerfile / apache.conf changes)

```bash
cd fahrni && docker compose build && docker compose up -d
cd ../pfadiheim-buelach && docker compose build && docker compose up -d
```

### Start containers (no rebuild needed)

```bash
cd fahrni && docker compose up -d
cd ../pfadiheim-buelach && docker compose up -d
```

### Site content updates (no container restart needed — bind mount)

```bash
cd fahrni/www && git pull origin main
cd pfadiheim-buelach/www && git pull origin main
```

### Logs

```bash
docker compose logs -f          # from inside the site directory
```

### Backup

```bash
bash scripts/backup.sh          # backs up content/, media/, accounts/, .license for all sites
```

Backups go to `~/kirby-backups/SITE/TIMESTAMP/`, keeping the last 14. Uses `rsync --link-dest` for deduplication.

## First-time server setup

```bash
# 1. Verify the traefik network exists
docker network ls | grep traefik

# 2. Clone site repos into www/ directories
git clone git@github.com:jfahrni/site-fahrni.git fahrni/www
git clone git@github.com:jfahrni/site-pfadiheim.git pfadiheim-buelach/www

# 3. Build image and start containers
cd fahrni && docker compose build && docker compose up -d
cd ../pfadiheim-buelach && docker compose build && docker compose up -d
```

## Deployment workflow

### Infrastructure changes (this repo)

Changes to `Dockerfile` or `apache.conf` require a manual rebuild on the server:

```bash
cd fahrni && docker compose build && docker compose up -d
cd ../pfadiheim-buelach && docker compose build && docker compose up -d
```

### Site updates (via CI/CD from site repos)

Site developers deploy via an SSH-based GitHub Actions workflow in their own repo. The workflow runs on the server:

```bash
cd fahrni/www && git pull origin main
# no container restart needed — code is bind-mounted
```

The infra admin must set up a dedicated SSH deploy key for each site owner once.

## Visual testing with Playwright

Playwright (Chrome) is installed and configured. Use it for screenshots and visual verification during design work.

```bash
# If Chrome is missing after a fresh setup:
npx playwright install chrome
```

MCP tools available: `mcp__playwright__browser_navigate`, `mcp__playwright__browser_take_screenshot`, `mcp__playwright__browser_snapshot` etc.
The live Pfadiheim site is at `https://www.pfadiheim-buelach.ch`.

## Adding a new site

1. Create `SITENAME/docker-compose.yml` based on `fahrni/docker-compose.yml`
2. Set Traefik labels with the correct domain
3. Add `SITENAME/www/` to `.gitignore`
4. On the server: clone the site repo to `SITENAME/www/`, start the container
5. Update this file (responsibilities table, architecture overview)

## Dependencies

| Component | Version | Note |
|---|---|---|
| Docker | 26+ | |
| Docker Compose | v2 (plugin) | use `docker compose`, not `docker-compose` |
| PHP | 8.4 | defined in `apache/Dockerfile` |
| Kirby CMS | — | provided by the site repo |

## Important constraints

- Kirby Panel edits write directly to `SITE/www/content/` on the server — they are **not** auto-committed to the site git repo. Editorial content and code deployment are intentionally decoupled.
- DB containers (if added later) must only join the internal network, never `traefik`.
- Never commit `www/` directories or `.env` files.
- All containers run with `no-new-privileges:true` — keep this for every new site.
- On a server rebuild, `SITE/www/content/` (plus `media/`, `site/accounts/`, `.license`) must be restored separately — that is what `scripts/backup.sh` covers; the git repos alone are not enough.
