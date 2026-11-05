#!/bin/bash

# Benutzerkonfiguration
ZONE_ID="{ZONE_ID}"
RECORD_ID="{RECORD_ID}"
API_TOKEN="{API_TOKEN}"
RECORD_NAME="{DOMAIN_NAME}"

# IP ermitteln
IP=$(curl -s --ipv4 https://ifconfig.me | tr -d '\n')

# Fehler prüfen
if [[ -z "$IP" ]]; then
    echo "Fehler: Konnte öffentliche IP nicht ermitteln."
    exit 1
fi

echo "Aktuelle öffentliche IP: $IP"


# Der DNS-Records bei Cloudflare aktualisieren
RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" -H "Authorization: Bearer $API_TOKEN" -H "Content-Type: application/json" --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$IP\",\"ttl\":120,\"proxied\":false}")

# auswerten
SUCCESS=$(echo "$RESPONSE" | grep -o '"success":true')

if [[ $SUCCESS ]]; then
    echo "DNS-Eintrag für $RECORD_NAME wurde erfolgreich auf $IP aktualisiert."
else
    echo "Fehler beim Aktualisieren des DNS-Eintrags:"
    echo "$RESPONSE"
    exit 1
fi