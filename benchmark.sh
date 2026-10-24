#!/bin/bash
# ==============================================================================
# Script de Benchmark Réseau & Performance Pilote Wi-Fi (RTL8821CE)
# Mesure : Latence locale, gigue, perte, débit réel, interruptions et CPU
# Format de sortie : Rapport Markdown horodaté dans benchmark_results/
# ==============================================================================

set -e

GATEWAY=$(ip route show default 2>/dev/null | awk '{print $3}' | head -n1)
IFACE=$(ip route show default 2>/dev/null | awk '{print $5}' | head -n1)
IFACE=${IFACE:-wlo1}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
HUMAN_DATE=$(date +"%d/%m/%Y %H:%M:%S")
OUTPUT_DIR="benchmark_results"
OUTPUT_FILE="${OUTPUT_DIR}/benchmark_${TIMESTAMP}.md"
TEST_URL="https://proof.ovh.net/files/100Mb.dat"

mkdir -p "$OUTPUT_DIR"

echo "=========================================================="
echo "    Benchmark Wi-Fi ($IFACE)"
echo "    Passerelle : $GATEWAY"
echo "    Fichier    : $OUTPUT_FILE"
echo "=========================================================="

# 1. Métadonnées du Pilote et du Système
KERNEL_VER=$(uname -r)
MODULE_VER=$(modinfo 8821ce 2>/dev/null | grep -E "^version:" | awk '{$1=""; print $0}' | xargs || echo "N/A")
SRC_VER=$(cat /sys/module/8821ce/srcversion 2>/dev/null || echo "Inconnu")

NM_INFO=$(nmcli -t -f active,ssid,bssid,chan,freq,signal dev wifi 2>/dev/null | grep '^yes:' || true)
if [ -n "$NM_INFO" ]; then
    SSID=$(echo "$NM_INFO" | cut -d':' -f2)
    BSSID=$(echo "$NM_INFO" | cut -d':' -f3-8)
    CHAN=$(echo "$NM_INFO" | cut -d':' -f9)
    SIGNAL="$(echo "$NM_INFO" | cut -d':' -f10) %"
else
    SSID="Non détecté"
    BSSID="N/A"
    CHAN="N/A"
    SIGNAL="N/A"
fi

# 2. Test de Latence & Gigue Locale vers la box
echo -n "[1/4] Mesure de la latence locale (50 pings)... "
PING_RAW=$(ping -c 50 -i 0.1 "$GATEWAY" 2>&1)
LOSS=$(echo "$PING_RAW" | grep -oP '\d+(?=% packet loss)')
RTT_LINE=$(echo "$PING_RAW" | grep -E "rtt|round-trip" || echo "")

if [ -n "$RTT_LINE" ]; then
    RTT_MIN=$(echo "$RTT_LINE" | awk -F'/' '{print $4}' | awk '{print $NF}')
    RTT_AVG=$(echo "$RTT_LINE" | awk -F'/' '{print $5}')
    RTT_MAX=$(echo "$RTT_LINE" | awk -F'/' '{print $6}')
    RTT_MDEV=$(echo "$RTT_LINE" | awk -F'/' '{print $7}' | awk '{print $1}')
else
    RTT_MIN="N/A"; RTT_AVG="N/A"; RTT_MAX="N/A"; RTT_MDEV="N/A"
fi
echo "OK (${RTT_AVG} ms avg, ${LOSS}% perte)"

# 3. Mesure des Interruptions Matérielles au repos
echo -n "[2/4] Mesure des interruptions matérielles... "
IRQ_BEFORE=$(grep -i "8821" /proc/interrupts 2>/dev/null | awk '{sum=0; for(i=2; i<=NF-2; i++) sum+=$i; print sum}' || echo 0)
sleep 1
IRQ_AFTER=$(grep -i "8821" /proc/interrupts 2>/dev/null | awk '{sum=0; for(i=2; i<=NF-2; i++) sum+=$i; print sum}' || echo 0)
IRQ_IDLE_DIFF=$((IRQ_AFTER - IRQ_BEFORE))
echo "OK ($IRQ_IDLE_DIFF irq/s au repos)"

# 4. Test de Débit Download Réel (Throughput sur 8 secondes)
echo -n "[3/4] Mesure du débit de téléchargement... "
DOWNLOAD_SPEED_BYTES=$(curl -o /dev/null -s -w '%{speed_download}' --max-time 8 "$TEST_URL" 2>/dev/null || echo 0)
SPEED_MBPS=$(awk "BEGIN {printf \"%.2f\", ($DOWNLOAD_SPEED_BYTES * 8) / 1000000}")
echo "OK ($SPEED_MBPS Mbit/s)"

# 5. Mesure CPU des threads du pilote (RTW_CMD_THREAD)
echo -n "[4/4] Mesure CPU du worker noyau du pilote... "
CMD_PID=$(pgrep -f "RTW_CMD_THREAD" | head -n1 || true)
if [ -n "$CMD_PID" ]; then
    CPU_USAGE=$(ps -p "$CMD_PID" -o %cpu --no-headers | xargs || echo "0.0")
else
    CPU_USAGE="0.0"
fi
echo "OK (${CPU_USAGE}% CPU)"

# 6. Écriture du rapport Markdown
cat <<EOF > "$OUTPUT_FILE"
# Rapport de Benchmark Pilote Wi-Fi RTL8821CE

**Date du test** : $HUMAN_DATE  
**Interface** : \`$IFACE\`  
**Noyau Linux** : \`$KERNEL_VER\`  

---

## 1. Empreinte du Pilote
| Paramètre | Valeur |
|---|---|
| **Version Pilote** | \`$MODULE_VER\` |
| **Signature Build (srcversion)** | \`$SRC_VER\` |
| **SSID Connecté** | \`$SSID\` |
| **BSSID AP** | \`$BSSID\` |
| **Canal Wi-Fi** | \`Canal $CHAN\` |
| **Puissance Signal (Qualité)** | \`$SIGNAL\` |

---

## 2. Performances Réseau (Qualité de Liaison)
| Métrique | Résultat | Appréciation |
|---|---|---|
| **Latence Minimale** | \`${RTT_MIN} ms\` | - |
| **Latence Moyenne** | \`${RTT_AVG} ms\` | $(awk "BEGIN {if ($RTT_AVG < 5) print \"Excellente (< 5ms)\"; else if ($RTT_AVG < 15) print \"Bonne (< 15ms)\"; else print \"Élevée (> 15ms)\"}") |
| **Latence Maximale** | \`${RTT_MAX} ms\` | - |
| **Gigue (Jitter / mdev)** | \`${RTT_MDEV} ms\` | $(awk "BEGIN {if ($RTT_MDEV < 3) print \"Très stable (< 3ms)\"; else print \"Fluctuante (> 3ms)\"}") |
| **Perte de Paquets** | \`${LOSS}%\` | $([ "$LOSS" -eq 0 ] && echo "Parfait (0%)" || echo "Anomalie (> 0%)") |
| **Débit Réel Mesuré** | \`${SPEED_MBPS} Mbit/s\` | - |

---

## 3. Impact Système & Matériel
| Métrique | Résultat |
|---|---|
| **Taux d'interruptions au repos** | \`${IRQ_IDLE_DIFF} irq/s\` |
| **Charge CPU du thread \`RTW_CMD_THREAD\`** | \`${CPU_USAGE}% CPU\` |

---
EOF

echo "=========================================================="
echo "    Benchmark terminé avec succès !"
echo "    Rapport généré : $OUTPUT_FILE"
echo "=========================================================="
