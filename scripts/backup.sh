#!/bin/bash
set -euo pipefail

SITES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="/home/jfahrni/kirby-backups"
KEEP=14
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
SKIP_DIRS="apache scripts"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

for SITE_PATH in "$SITES_DIR"/*/; do
    SITE=$(basename "$SITE_PATH")

    # Skip non-site directories
    if echo "$SKIP_DIRS" | grep -qw "$SITE"; then
        continue
    fi

    WWW="$SITE_PATH/www"
    if [ ! -d "$WWW" ]; then
        continue
    fi

    DEST="$BACKUP_DIR/$SITE/$TIMESTAMP"
    LATEST="$BACKUP_DIR/$SITE/latest"
    mkdir -p "$DEST"

    LINK_DEST_OPT=""
    if [ -L "$LATEST" ] && [ -d "$LATEST" ]; then
        LINK_DEST_OPT="--link-dest=$LATEST"
    fi

    # Directories and files to back up (everything not in git)
    SOURCES=()
    [ -d "$WWW/content" ]              && SOURCES+=("$WWW/content")
    [ -d "$WWW/public/media" ]         && SOURCES+=("$WWW/public/media")
    [ -d "$WWW/media" ]                && SOURCES+=("$WWW/media")
    [ -d "$WWW/site/accounts" ]        && SOURCES+=("$WWW/site/accounts")
    [ -d "$WWW/storage/accounts" ]     && SOURCES+=("$WWW/storage/accounts")
    [ -f "$WWW/site/config/.license" ] && SOURCES+=("$WWW/site/config/.license")

    if [ ${#SOURCES[@]} -eq 0 ]; then
        log "SKIP $SITE: keine relevanten Verzeichnisse gefunden"
        rmdir "$DEST"
        continue
    fi

    log "Starte Backup: $SITE -> $DEST"
    for SRC in "${SOURCES[@]}"; do
        RELATIVE="${SRC#$WWW/}"
        TARGET_DIR="$DEST/$(dirname "$RELATIVE")"
        mkdir -p "$TARGET_DIR"
        rsync -a --delete $LINK_DEST_OPT "$SRC" "$TARGET_DIR/"
    done

    # Symlink "latest" aktualisieren
    ln -sfn "$DEST" "$LATEST"

    # Rotation: nur die letzten $KEEP Backups behalten
    ls -dt "$BACKUP_DIR/$SITE"/[0-9][0-9][0-9][0-9]-* 2>/dev/null \
        | tail -n +$((KEEP + 1)) \
        | xargs -r rm -rf

    SIZE=$(du -sh "$DEST" | cut -f1)
    log "Fertig: $SITE ($SIZE)"
done

log "Backup abgeschlossen."
