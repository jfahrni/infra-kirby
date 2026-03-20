# infra-kirby

Docker-Hosting-Infrastruktur für Kirby-CMS-Sites hinter einem Traefik Reverse Proxy.

Dieses Repository verwaltet das gemeinsame Apache/PHP-Basis-Image sowie die Container-Definitionen der einzelnen Sites. **Der eigentliche Seiteninhalt (Kirby-Installationen) gehört nicht in dieses Repo** und wird in separaten Repositories verwaltet.

---

## Struktur

```
infra-kirby/
├── apache/                          # Gemeinsames Basis-Image für alle Sites
│   ├── Dockerfile                   # PHP 8.3 + Apache
│   └── apache.conf                  # Apache VirtualHost (DocumentRoot: /var/www/site/public)
├── fahrni/
│   ├── docker-compose.yml           # Container-Definition für new.fahrni.ch
│   └── www/                         # ← Kirby-Site-Repo (separates Git-Repo, nicht eingecheckt)
└── pfadiheim-buelach/
    ├── docker-compose.yml           # Container-Definition für new.pfadiheim-buelach.ch
    └── www/                         # ← Kirby-Site-Repo (separates Git-Repo, nicht eingecheckt)
```

### Warum sind die `www/`-Verzeichnisse ausgeschlossen?

Die eigentlichen Kirby-Sites (`fahrni/www/`, `pfadiheim-buelach/www/`) sind in `.gitignore` eingetragen und werden **nicht** in diesem Repo versioniert. Jede Site hat ihr eigenes Git-Repository, das von den jeweiligen Entwicklern gepflegt wird. Auf dem Server werden sie separat in die `www/`-Verzeichnisse geclont.

Diese Trennung erlaubt es, Infrastruktur (Docker, Apache) und Applikationscode unabhängig voneinander zu deployen.

---

## Architektur

```
Internet
    │
Traefik (separates Repo, verwaltet SSL & Routing)
    │
    ├── new.fahrni.ch ──────────────► Apache+PHP Container (fahrni/)
    │
    └── new.pfadiheim-buelach.ch ───► Apache+PHP Container (pfadiheim-buelach/)
```

- Alle Container hängen im externen Docker-Netzwerk `traefik` (von Traefik verwaltet).
- Jede Site hat zusätzlich ein internes Netzwerk (für zukünftige DB-Container).
- Die Traefik-Labels in den `docker-compose.yml`-Dateien sind die einzige Schnittstelle zu Traefik.

### Kirby Public-Folder-Setup

Die Kirby-Sites verwenden ein Public-Folder-Layout:

```
www/
├── public/          # Apache DocumentRoot
│   ├── index.php    # Einstiegspunkt (referenziert übergeordnete Verzeichnisse)
│   ├── assets/      # CSS, JS, Bilder
│   ├── media/       # Von Kirby generierte Thumbnails etc.
│   └── .htaccess
├── content/         # Seiteninhalte (nicht öffentlich zugänglich)
├── site/            # Templates, Blueprints, Plugins
├── storage/         # Accounts, Cache, Sessions (nicht öffentlich zugänglich)
├── kirby/           # Kirby CMS Core
└── vendor/          # Composer-Abhängigkeiten
```

Nur `public/` ist über den Browser erreichbar. Alle anderen Verzeichnisse liegen ausserhalb des Document Root.

---

## Erstmaliges Setup auf dem Server

### 1. Voraussetzung

Das externe Docker-Netzwerk `traefik` muss bereits existieren (vom Traefik-Repo erstellt):

```bash
docker network ls | grep traefik
```

### 2. Dieses Repo clonen

```bash
git clone git@github.com:jfahrni/infra-kirby.git ~/infra-kirby
cd ~/infra-kirby
```

### 3. Site-Repos clonen

```bash
git clone git@github.com:jfahrni/site-fahrni.git fahrni/www
git clone git@github.com:jfahrni/site-pfadiheim.git pfadiheim-buelach/www
```

### 4. Container starten

```bash
# Fahrni
cd fahrni && docker compose up -d

# Pfadiheim
cd ../pfadiheim-buelach && docker compose up -d
```

---

## Deployment

### Infrastruktur-Änderungen (dieses Repo)

Änderungen an `Dockerfile` oder `apache.conf` erfordern einen Rebuild:

```bash
cd fahrni && docker compose build && docker compose up -d
cd pfadiheim-buelach && docker compose build && docker compose up -d
```

### Site-Updates

Site-Entwickler deployen über einen SSH-basierten GitHub Actions Workflow direkt aus ihrem Site-Repo:

```bash
cd ~/infra-kirby/fahrni/www && git pull origin main
# Kein Container-Neustart nötig – Code ist per Bind Mount eingehängt
```

---

## Neue Site hinzufügen

1. Neues Verzeichnis anlegen: `mkdir SITENAME`
2. `docker-compose.yml` analog zu `fahrni/` erstellen
3. Traefik-Labels mit korrekter Domain setzen
4. `SITENAME/www/` in `.gitignore` eintragen
5. Diese README aktualisieren
6. Auf dem Server: Site-Repo nach `SITENAME/www/` clonen, Container starten

---

## Technische Details

| Komponente     | Version       |
|----------------|---------------|
| PHP            | 8.3           |
| Apache         | via php:8.3-apache |
| Docker Compose | v2 (Plugin)   |
| Kirby CMS      | ^5.2 (im Site-Repo) |

**PHP-Konfiguration:**
- Extensions: `gd`, `zip`
- Upload-Limit: 32 MB

**Sicherheit:**
- Alle Container laufen mit `no-new-privileges:true`
- DB-Container (falls künftig hinzugefügt) nur im internen Netzwerk, nie in `traefik`
- `www/`-Verzeichnisse und `.env`-Dateien niemals committen
