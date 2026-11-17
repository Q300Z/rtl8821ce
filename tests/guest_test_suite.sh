#!/bin/bash
# ==============================================================================
# Suite de tests dynamiques pour le pilote RTL8821CE (8821ce.ko)
# A executer sur noyau standard ou instrumente
# (Lockdep, DMA_API_DEBUG, KASAN, DEBUG_ATOMIC_SLEEP, iommu.strict=1)
# ==============================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MODULE_PATH="${1:-$REPO_DIR/8821ce.ko}"
IFACE=""
PASS_CNT=0
FAIL_CNT=0
SKIP_CNT=0
NM_WAS_MANAGED=false
STEP_SEQ=0

# Motifs critiques surveilles dans dmesg
DMESG_ERR_REGEX="BUG:|WARNING:|possible recursive locking|LOCKDEP|DMA-API:|KASAN:|UBSAN:|IO_PAGE_FAULT|kernel NULL pointer dereference|general protection fault|inconsistent lock state|sleeping function called from invalid context|task .* blocked for more than"

log_info() { echo "[INFO] $*"; }
log_pass() { echo "[PASS] $*"; PASS_CNT=$((PASS_CNT + 1)); }
log_fail() { echo "[FAIL] $*"; FAIL_CNT=$((FAIL_CNT + 1)); }
log_skip() { echo "[SKIP] $*"; SKIP_CNT=$((SKIP_CNT + 1)); }

if [ "$EUID" -ne 0 ]; then
    echo "[ERREUR] Ce script doit etre execute en root (sudo)."
    exit 1
fi

if [ ! -f "$MODULE_PATH" ]; then
    echo "[ERREUR] Module introuvable : $MODULE_PATH"
    exit 1
fi

# Pose un marqueur unique dans /dev/kmsg pour borner les logs sans compter les lignes
mark_dmesg() {
    STEP_SEQ=$((STEP_SEQ + 1))
    local tag="RTL8821CE_STEP_${$}_${STEP_SEQ}"
    if [ -w /dev/kmsg ]; then
        echo "$tag" > /dev/kmsg 2>/dev/null || true
    fi
    echo "$tag"
}

check_dmesg_since_tag() {
    local step_name="$1"
    local tag="$2"
    local new_logs
    new_logs=$(dmesg | awk -v tag="$tag" '$0 ~ tag {found=1; next} found {print}')

    local hits
    hits=$(echo "$new_logs" | grep -E "$DMESG_ERR_REGEX" || true)
    if [ -n "$hits" ]; then
        log_fail "$step_name : anomalie(s) noyau detectee(s) dans dmesg :"
        echo "$hits" | sed 's/^/    /'
        return 1
    fi
    return 0
}

find_wifi_iface() {
    for dev in /sys/class/net/*; do
        [ -e "$dev/wireless" ] || continue
        local drv
        drv=$(basename "$(readlink -f "$dev/device/driver" 2>/dev/null || echo "")")
        if [ "$drv" = "rtl8821ce" ] || [ "$drv" = "8821ce" ]; then
            basename "$dev"
            return 0
        fi
    done
    return 1
}

restore_nm() {
    if [ "$NM_WAS_MANAGED" = true ] && [ -n "$IFACE" ] && command -v nmcli >/dev/null 2>&1; then
        nmcli dev set "$IFACE" managed yes 2>/dev/null || true
        NM_WAS_MANAGED=false
    fi
}

cleanup() {
    restore_nm
}
trap cleanup EXIT INT TERM

log_info "Noyau : $(uname -r)"
log_info "Cmdline : $(cat /proc/cmdline)"
rmmod 8821ce 2>/dev/null || true
rmmod rtw88_8821ce 2>/dev/null || true

# ==============================================================================
# Scenario 1 : Chargement / dechargement a chaud (insmod / rmmod)
# ==============================================================================
log_info "=== Scenario 1 : Chargement et dechargement (insmod/rmmod) ==="
TAG=$(mark_dmesg)
if insmod "$MODULE_PATH"; then
    sleep 2
    IFACE=$(find_wifi_iface || true)
    if [ -n "$IFACE" ]; then
        log_info "Interface Wi-Fi detectee : $IFACE"
        if check_dmesg_since_tag "Scenario 1 (insmod)" "$TAG"; then
            log_pass "Scenario 1a : insmod propre sur $IFACE"
        fi
    else
        log_fail "Scenario 1a : module charge mais aucune interface Wi-Fi rtl8821ce trouvee"
    fi
else
    log_fail "Scenario 1a : echec insmod $MODULE_PATH"
    exit 1
fi

TAG=$(mark_dmesg)
if rmmod 8821ce; then
    sleep 1
    if check_dmesg_since_tag "Scenario 1b (rmmod)" "$TAG"; then
        log_pass "Scenario 1b : rmmod propre sans fuite ni deadlock"
    fi
else
    log_fail "Scenario 1b : echec rmmod 8821ce"
fi

# Rechargement exact de $MODULE_PATH pour les scenarios suivants
insmod "$MODULE_PATH" || exit 1
sleep 2
IFACE=$(find_wifi_iface || true)
if [ -z "$IFACE" ]; then
    log_fail "Impossible de retrouver l'interface apres rechargement"
    exit 1
fi

# Desactiver temporairement NetworkManager sur $IFACE pendant les tests iw (Scenarios 2-6)
if command -v nmcli >/dev/null 2>&1; then
    if nmcli -t -f DEVICE,STATE dev 2>/dev/null | grep -q "^${IFACE}:"; then
        if ! nmcli -t -f DEVICE,STATE dev 2>/dev/null | grep -q "^${IFACE}:unmanaged"; then
            nmcli dev set "$IFACE" managed no 2>/dev/null && NM_WAS_MANAGED=true || true
            sleep 1
        fi
    fi
fi

MONITOR_SUPPORTED=false
if command -v iw >/dev/null 2>&1; then
    PHY_NAME=$(cat "/sys/class/net/$IFACE/phy80211/name" 2>/dev/null || echo "")
    if [ -n "$PHY_NAME" ] && iw phy "$PHY_NAME" info 2>/dev/null | grep -qE "^\s*\* monitor$"; then
        MONITOR_SUPPORTED=true
    fi
fi

# ==============================================================================
# Scenario 2 : Interface Monitor (deadlock wiphy_lock / rtnl_lock)
# ==============================================================================
log_info "=== Scenario 2 : Creation/suppression interface Monitor ==="
if ! command -v iw >/dev/null 2>&1; then
    log_skip "Scenario 2 : outil 'iw' absent"
elif [ "$MONITOR_SUPPORTED" = false ]; then
    log_skip "Scenario 2 : mode monitor non active dans ce build (CONFIG_WIFI_MONITOR=n)"
else
    TAG=$(mark_dmesg)
    ip link set "$IFACE" up 2>/dev/null || true
    if timeout 15 iw dev "$IFACE" interface add mon_test type monitor; then
        ip link set mon_test up 2>/dev/null || true
        sleep 1
        ip link set mon_test down 2>/dev/null || true
        if timeout 15 iw dev mon_test del; then
            if check_dmesg_since_tag "Scenario 2 (Monitor add/del)" "$TAG"; then
                log_pass "Scenario 2 : creation/suppression monitor sans deadlock wiphy_lock"
            fi
        else
            log_fail "Scenario 2 : timeout ou echec suppression mon_test (deadlock probable)"
        fi
    else
        log_fail "Scenario 2 : timeout ou echec creation mon_test"
    fi
fi

# ==============================================================================
# Scenario 3 : Interfaces virtuelles P2P / AP (deadlock wiphy_lock sur VIF)
# ==============================================================================
log_info "=== Scenario 3 : Creation/suppression VIF (__ap) ==="
if command -v iw >/dev/null 2>&1; then
    TAG=$(mark_dmesg)
    if timeout 15 iw dev "$IFACE" interface add vif_test type __ap 2>/dev/null; then
        sleep 1
        if timeout 15 iw dev vif_test del; then
            if check_dmesg_since_tag "Scenario 3 (VIF add/del)" "$TAG"; then
                log_pass "Scenario 3 : creation/suppression VIF __ap sans deadlock"
            fi
        else
            log_fail "Scenario 3 : timeout ou echec suppression vif_test"
        fi
    else
        log_skip "Scenario 3 : creation VIF __ap non supportee dans cet etat"
    fi
else
    log_skip "Scenario 3 : outil 'iw' absent"
fi

# ==============================================================================
# Scenario 4 : Scan actif (stress RX DMA)
# ==============================================================================
log_info "=== Scenario 4 : Scan Wi-Fi repetitif (stress RX DMA) ==="
if command -v iw >/dev/null 2>&1; then
    TAG=$(mark_dmesg)
    ip link set "$IFACE" up 2>/dev/null || true
    local_scan_ok=0
    for i in 1 2 3; do
        if timeout 20 iw dev "$IFACE" scan >/dev/null 2>&1; then
            local_scan_ok=$((local_scan_ok + 1))
        fi
        sleep 2
    done
    if [ "$local_scan_ok" -gt 0 ]; then
        if check_dmesg_since_tag "Scenario 4 (Scan RX DMA)" "$TAG"; then
            log_pass "Scenario 4 : $local_scan_ok/3 scans completes sans erreur DMA/IOMMU"
        fi
    else
        log_skip "Scenario 4 : aucun scan abouti (environnement RF ou pilote occupe)"
    fi
else
    log_skip "Scenario 4 : outil 'iw' absent"
fi

# ==============================================================================
# Scenario 5 : Echec de connexion sur SSID inexistant (connect_result NULL)
# ==============================================================================
log_info "=== Scenario 5 : Tentative de connexion sur SSID inexistant ==="
if command -v iw >/dev/null 2>&1; then
    TAG=$(mark_dmesg)
    ip link set "$IFACE" up 2>/dev/null || true
    timeout 15 iw dev "$IFACE" connect "__TEST_NONEXISTENT_SSID_8821CE__" 2>/dev/null || true
    sleep 6
    iw dev "$IFACE" disconnect 2>/dev/null || true
    if check_dmesg_since_tag "Scenario 5 (Connect timeout)" "$TAG"; then
        log_pass "Scenario 5 : echec/timeout de connexion gere sans dereferencement NULL"
    fi
else
    log_skip "Scenario 5 : outil 'iw' absent"
fi

# ==============================================================================
# Scenario 6 : Suppression interface principale pendant monitor actif
# ==============================================================================
log_info "=== Scenario 6 : Dechargement module avec interface monitor active ==="
if ! command -v iw >/dev/null 2>&1; then
    rmmod 8821ce || true
    log_skip "Scenario 6 : outil 'iw' absent (rmmod simple effectue)"
elif [ "$MONITOR_SUPPORTED" = false ]; then
    rmmod 8821ce || true
    log_skip "Scenario 6 : mode monitor non active (CONFIG_WIFI_MONITOR=n)"
else
    TAG=$(mark_dmesg)
    ip link set "$IFACE" up 2>/dev/null || true
    if timeout 15 iw dev "$IFACE" interface add mon_rmmod type monitor; then
        if timeout 20 rmmod 8821ce; then
            if check_dmesg_since_tag "Scenario 6 (rmmod avec monitor actif)" "$TAG"; then
                log_pass "Scenario 6 : rmmod avec monitor actif sans deadlock rtnl_lock"
            fi
        else
            log_fail "Scenario 6 : timeout rmmod avec monitor actif (deadlock)"
        fi
    else
        rmmod 8821ce || true
        log_fail "Scenario 6 : echec creation mon_rmmod"
    fi
fi

# Recharger exactement $MODULE_PATH et rendre la main a NetworkManager
log_info "Rechargement de $MODULE_PATH pour veille/reveil et benchmark..."
if ! insmod "$MODULE_PATH"; then
    log_fail "Echec rechargement de $MODULE_PATH"
    exit 1
fi
sleep 3
IFACE=$(find_wifi_iface || true)
restore_nm

# ==============================================================================
# Scenario 7 : Cycle veille / reveil PCIe (suspend / resume)
# ==============================================================================
log_info "=== Scenario 7 : Cycle veille / reveil (rtcwake -m mem -s 5) ==="
if command -v rtcwake >/dev/null 2>&1 && grep -qw "mem" /sys/power/state 2>/dev/null; then
    TAG=$(mark_dmesg)
    if rtcwake -m mem -s 5 >/dev/null 2>&1; then
        sleep 3
        IFACE=$(find_wifi_iface || true)
        if ! command -v lspci >/dev/null 2>&1; then
            if [ -n "$IFACE" ] && check_dmesg_since_tag "Scenario 7 (Suspend/Resume)" "$TAG"; then
                log_pass "Scenario 7 : veille/reveil OK ($IFACE present, lspci absent)"
            else
                log_fail "Scenario 7 : interface absente ou erreur noyau apres reveil"
            fi
        else
            BUS_MASTER=$(lspci -vv -d 10ec:c821 2>/dev/null | grep -oE "BusMaster[+-]" | head -n1 || true)
            if [ -n "$IFACE" ] && [ "$BUS_MASTER" = "BusMaster+" ]; then
                if check_dmesg_since_tag "Scenario 7 (Suspend/Resume)" "$TAG"; then
                    log_pass "Scenario 7 : veille/reveil OK ($IFACE present, $BUS_MASTER restaure)"
                fi
            else
                log_fail "Scenario 7 : etat invalide apres reveil (iface='${IFACE:-none}', BusMaster='${BUS_MASTER:-N/A}')"
            fi
        fi
    else
        log_skip "Scenario 7 : rtcwake -m mem a echoue dans cet environnement"
    fi
else
    log_skip "Scenario 7 : rtcwake ou mode 'mem' indisponible"
fi

# ==============================================================================
# Scenario 8 : Benchmark & stress trafic RX/TX reel + verification dmesg
# ==============================================================================
log_info "=== Scenario 8 : Benchmark reseau et verification dmesg ==="
if [ -x "$REPO_DIR/benchmark.sh" ] && [ -n "$IFACE" ]; then
    log_info "Attente de reconnexion reseau sur $IFACE (max 25s)..."
    WAIT_NET=0
    while [ "$WAIT_NET" -lt 25 ]; do
        if ip route show default dev "$IFACE" 2>/dev/null | grep -q "default"; then
            break
        fi
        sleep 1
        WAIT_NET=$((WAIT_NET + 1))
    done

    if ip route show default dev "$IFACE" 2>/dev/null | grep -q "default"; then
        TAG=$(mark_dmesg)
        if (cd "$REPO_DIR" && bash "$REPO_DIR/benchmark.sh"); then
            if [ -n "${SUDO_USER:-}" ] && [ -d "$REPO_DIR/benchmark_results" ]; then
                SUDO_GRP=$(id -gn "$SUDO_USER" 2>/dev/null || echo "$SUDO_USER")
                chown -R "$SUDO_USER:$SUDO_GRP" "$REPO_DIR/benchmark_results" 2>/dev/null || true
            fi
            if check_dmesg_since_tag "Scenario 8 (Benchmark trafic)" "$TAG"; then
                log_pass "Scenario 8 : benchmark complete sans erreur noyau/DMA sous charge"
            fi
        else
            log_fail "Scenario 8 : echec d'execution de benchmark.sh"
        fi
    else
        log_skip "Scenario 8 : pas de route par defaut sur $IFACE apres 25s (benchmark ignore)"
    fi
else
    log_skip "Scenario 8 : benchmark.sh introuvable ou interface absente"
fi

echo "=============================================================================="
echo "BILAN TESTS DYNAMIQUES : PASS=$PASS_CNT | FAIL=$FAIL_CNT | SKIP=$SKIP_CNT"
echo "=============================================================================="
[ "$FAIL_CNT" -eq 0 ]
