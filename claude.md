# Infra-Repo – Kirby/Apache Hosting

Dieses Repository enthält die Docker-Konfiguration für das Hosting der Kirby-Sites.
Es verwaltet das gemeinsame Apache/PHP-Basis-Image sowie die Container-Definitionen der einzelnen Sites.
**Kein Applikationscode gehört in dieses Repo.**

Die Container laufen hinter einem Traefik Reverse Proxy (separates Repo/Zuständigkeit).

---

## Verantwortlichkeiten

| Bereich | Repo | Owner |
|---|---|---|
| Kirby-Hosting (Docker/Apache) | dieses Repo (`infra-kirby`) | Server-Admin |
| Traefik / SSL / Routing | separates Infra-Repo | Server-Admin |
| Site pfadiheim-buelach.ch | `site-pfadiheim` | Entwickler Pfadiheim |
| Site fahrni.ch | `site-fahrni` | Entwickler Fahrni |

---

## Repo-Struktur

```
infra-kirby/
├── CLAUDE.md                        ← diese Datei
├── kirby/
│   ├── Dockerfile                   ← gemeinsames Basis-Image für alle Kirby-Sites
│   └── apache.conf                  ← Apache VirtualHost-Konfiguration
├── pfadiheim-buelach/
│   ├── docker-compose.yml           ← Container-Definition für pfadiheim-buelach.ch
│   └── www/                         ← Kirby-Site-Repo (separates Git-Repo)
└── fahrni/
    ├── docker-compose.yml           ← Container-Definition für fahrni.ch
    └── www/                         ← Kirby-Site-Repo (separates Git-Repo)
```

---

## Server-Struktur (auf dem Host)

```
/home/<user>/
├── infra-kirby/                     ← dieses Repo (vollständig geclont)
│   ├── kirby/                       ← gemeinsames Basis-Image (Dockerfile, apache.conf)
│   ├── pfadiheim-buelach/           ← Kirby-Installation + docker-compose.yml
│   └── fahrni/                      ← Kirby-Installation + docker-compose.yml
```

---

## Architektur

```
Traefik (extern, separates Repo)
    │
    ├──── new.pfadiheim-buelach.ch ──► Apache+PHP Container  (/home/<user>/infra-kirby/pfadiheim-buelach)
    │
    └──── www.fahrni.ch ─────────────► Apache+PHP Container  (/home/<user>/infra-kirby/fahrni)
```

- Alle Container hängen im externen Docker-Netzwerk `traefik-proxy` (wird von Traefik verwaltet).
- Jede Site hat zusätzlich ein eigenes internes Netzwerk (für zukünftige DB-Container etc.).
- Die Traefik-Labels in den `docker-compose.yml` sind die einzige Schnittstelle zu Traefik –
  mehr Traefik-Konfiguration gehört nicht in dieses Repo.

---

## Erstmaliges Setup auf dem Server

### 1. Voraussetzung prüfen

Das externe Docker-Netzwerk `traefik-proxy` muss bereits existieren (wird vom Traefik-Repo erstellt):

```bash
docker network ls | grep traefik-proxy
```

### 2. Dieses Repo clonen

```bash
git clone git@github.com:OWNER/infra-kirby.git /home/<user>/infra-kirby
```

### 3. Site-Repos clonen

```bash
git clone git@github.com:OWNER/site-pfadiheim.git /home/<user>/infra-kirby/pfadiheim-buelach/www
git clone git@github.com:OWNER/site-fahrni.git /home/<user>/infra-kirby/fahrni/www
```

### 4. Kirby-Image bauen und Container starten

```bash
# Pfadiheim
cd /home/<user>/infra-kirby/pfadiheim-buelach
docker compose build
docker compose up -d

# Fahrni
cd /home/<user>/infra-kirby/fahrni
docker compose build
docker compose up -d
```

---

## Deployment-Workflow

### Infrastruktur-Änderungen (dieses Repo)

Änderungen an Dockerfile oder Apache-Konfiguration erfordern manuelle Schritte auf dem Server:

```bash
# Bei Dockerfile-Änderungen: Image neu bauen
cd /home/<user>/infra-kirby/pfadiheim-buelach && docker compose build && docker compose up -d
cd /home/<user>/infra-kirby/fahrni && docker compose build && docker compose up -d
```

### Site-Updates (via CI/CD aus den Site-Repos)

Site-Entwickler deployen über einen SSH-basierten GitHub Actions Workflow in ihrem Repo.
Der Workflow führt auf dem Server aus:

```bash
cd /home/<user>/infra-kirby/pfadiheim-buelach/www && git pull origin main
# kein Container-Neustart nötig – Code ist per Bind Mount eingehängt
```

Der Infra-Admin muss dafür einmalig einen dedizierten SSH-Key für jeden Site-Owner hinterlegen.

---

## Konfigurationsdetails

### Kirby-Container (gemeinsames Basis-Image)

- Basis: `php:8.3-apache`
- PHP-Extensions: `gd`, `zip` (Kirby-Anforderungen)
- Apache: `mod_rewrite` aktiviert, `AllowOverride All` für `.htaccess`
- Upload-Limits: `upload_max_filesize=32M`, `post_max_size=32M`

### Netzwerke

| Netzwerk | Typ | Verwendet von |
|---|---|---|
| `traefik-proxy` | extern, bridge | von Traefik verwaltet, alle Web-Container hängen sich ein |
| `pfadiheim-internal` | intern | nur pfadiheim-buelach-Container |
| `fahrni-internal` | intern | nur fahrni-Container |

---

## Sicherheitshinweise

- Alle Container laufen mit `no-new-privileges:true`
- Datenbank-Container (falls später hinzugefügt) nur im internen Netzwerk, nie in `traefik-proxy`
- `.env`-Dateien mit Secrets niemals ins Git committen

---

## Neue Site hinzufügen

1. Neues Verzeichnis `infra/SITENAME/` anlegen
2. `docker-compose.yml` analog zu `pfadiheim-buelach/` erstellen
3. Traefik-Labels mit korrekter Domain setzen
4. Auf dem Server: Verzeichnis anlegen, Site-Repo clonen, Container starten
5. Diese Datei aktualisieren (Tabelle Verantwortlichkeiten, Architektur-Übersicht)

---

## Abhängigkeiten & Versionen

| Komponente | Version | Anmerkung |
|---|---|---|
| Docker | 26+ | |
| Docker Compose | v2 (Plugin) | `docker compose`, nicht `docker-compose` |
| PHP | 8.3 | im Kirby-Dockerfile definiert |
| Kirby CMS | — | wird vom Site-Repo mitgebracht |

---

## Bekannte Einschränkungen

- Kirby Panel-Uploads und Content-Änderungen über das Panel schreiben direkt in `/home/<user>/infra-kirby/SITE/www/content/`
  auf dem Server. Diese Änderungen sind **nicht automatisch im Site-Git-Repo**.
  Redaktioneller Content und Code-Deployment sind bewusst getrennt.
- Bei einem Server-Rebuild muss `/home/<user>/infra-kirby/SITE/www/content/` separat gesichert und wiederhergestellt werden.
  Siehe Backup-Strategie (noch zu dokumentieren).
