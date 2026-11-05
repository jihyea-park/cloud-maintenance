#!/bin/bash

# Variablen
BACKUP_DIR="{BACKUP_DIR}"
NC_PATH="/var/www/nextcloud"
NC_DATA="/var/www/nextcloud/data"
DATE=$(date +"%Y-%m-%d_%H-%M")
DB_NAME="{DB_NAME}"
GPG_RECIPIENT="{MAIL-ADRESSE}"
MYCNF="/root/.my.cnf"

# Sicherstellen, dass das Backup-Dateisystem eingehängt ist
if ! mountpoint -q "$BACKUP_DIR"; then
    echo "Backup-Verzeichnis ist nicht eingehängt. Versuche es einzuhängen..."

    if ! mount "$BACKUP_DIR"; then
        echo "FEHLER: Einhängen von $BACKUP_DIR fehlgeschlagen. Backup abgebrochen!"
        exit 1
    fi
fi

# Nochmals prüfen, damit niemals versehentlich auf die Systemplatte geschrieben wird
if ! mountpoint -q "$BACKUP_DIR"; then
    echo "FEHLER: $BACKUP_DIR ist nach dem Einhängeversuch weiterhin kein Mountpoint."
    echo "Backup abgebrochen!"
    exit 1
fi

echo "Backup-Dateisystem ist eingehängt."

# Wartungsmodus aktivieren
sudo -u www-data php $NC_PATH/occ maintenance:mode --on

# Backup erstellen
echo "Erstelle Dateibackup..."
tar -czf "$BACKUP_DIR/nc-files_$DATE.tar.gz" -C "$NC_PATH" .

echo "Erstelle Datenbankdump..."
mariadb-dump --defaults-extra-file="$MYCNF" "$DB_NAME" > "$BACKUP_DIR/nc-db_$DATE.sql"

# Wartungsmodus deaktivieren
sudo -u www-data php $NC_PATH/occ maintenance:mode --off

# GPG-Verschlüsselung
echo "Verschlüssle Backups..."

FILES="$BACKUP_DIR/nc-files_$DATE.tar.gz"
DB="$BACKUP_DIR/nc-db_$DATE.sql"
FILES_GPG="$FILES.gpg"
DB_GPG="$DB.gpg"

if ! gpg --yes --batch --trust-model always \
    --output "$FILES_GPG" \
    --encrypt --recipient "$GPG_RECIPIENT" "$FILES"; then
    echo "FEHLER: Verschlüsselung des Dateibackups fehlgeschlagen."
    exit 1
fi

if ! gpg --yes --batch --trust-model always \
    --output "$DB_GPG" \
    --encrypt --recipient "$GPG_RECIPIENT" "$DB"; then
    echo "FEHLER: Verschlüsselung des Datenbankbackups fehlgeschlagen."
    exit 1
fi

# Prüfen, dass beide verschlüsselten Dateien vorhanden und nicht leer sind
if [ ! -s "$FILES_GPG" ] || [ ! -s "$DB_GPG" ]; then
    echo "FEHLER: Mindestens eine verschlüsselte Datei fehlt oder ist leer."
    exit 1
fi

# Erst jetzt die unverschlüsselten Originale löschen
rm -- "$FILES" "$DB" || {
    echo "FEHLER: Unverschlüsselte Dateien konnten nicht vollständig gelöscht werden."
    exit 1
}

echo "Verschlüsselung erfolgreich; unverschlüsselte Dateien gelöscht."

# Backup-Datei älter als 15 Tagen löschen
find "$BACKUP_DIR" -maxdepth 1 -type f \
    \( -name 'nc-files_*.gpg' -o -name 'nc-db_*.gpg' \) \
    -mtime +15 -delete

echo "Backup abgeschlossen: $DATE"