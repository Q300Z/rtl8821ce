#!/bin/bash

# ==============================================================================
# Script d'analyse statique optimisé pour le pilote RTL8821CE
# Outil : Cppcheck
# Objectif : Détecter les erreurs logiques, fuites mémoire et défauts de style.
# ==============================================================================

# --- Configuration des ressources ---
# CPU_CORES : Récupère le nombre de processeurs logiques pour le parallélisme.
CPU_CORES=$(nproc)
# OUTPUT_FILE : Fichier où seront écrits les résultats de l'analyse.
OUTPUT_FILE="cppcheck_results.txt"
# CACHE_DIR : Dossier stockant l'état de l'analyse précédente (évite de re-analyser l'inchangé).
CACHE_DIR="build_cache"

# --- Localisation des headers noyau ---
# Indispensable pour que Cppcheck comprenne les structures complexes comme sk_buff.
KERNEL_VER=$(uname -r)
KERNEL_DIR="/lib/modules/$KERNEL_VER/build"

# --- Initialisation des options ---
USE_KERNEL=false
USE_FORCE="--force" # Par défaut, on teste toutes les combinaisons de #ifdef (Précis mais Lent)
FAST_MODE=false

# --- Analyse des arguments passés au script ---
for arg in "$@"; do
    case $arg in
        --with-kernel)
            # Active l'inclusion des headers système du noyau Linux.
            USE_KERNEL=true
            ;;
        --fast)
            # Désactive l'exploration exhaustive de toutes les macros (#ifdef).
            # Gain de temps massif sur les gros projets de pilotes.
            FAST_MODE=true
            USE_FORCE="" 
            ;;
    esac
done

# --- Préparation de l'environnement ---
# Création du dossier de cache s'il n'existe pas encore.
if [ ! -d "$CACHE_DIR" ]; then
    mkdir -p "$CACHE_DIR"
fi

echo "================================================="
echo "   Analyse statique RTL8821CE avec Cppcheck"
echo "================================================="
echo "Coeurs utilisés    : $CPU_CORES"
echo "Fichier de sortie  : $OUTPUT_FILE"
echo "Dossier de cache   : $CACHE_DIR"

if [ "$FAST_MODE" = true ]; then
    echo "Mode               : Rapide (Ignore les combinaisons de macros rares)"
else
    echo "Mode               : Exhaustif (Analyse toutes les branches #ifdef)"
fi

# --- Construction des chemins d'inclusion ---
# On cherche dynamiquement tous les dossiers contenant des fichiers .h
# -not -path "./.*" : Ignore les dossiers cachés (ex: .git, .github)
# -not -path "./build_cache*" : Ignore le dossier de cache pour ne pas polluer l'analyse
# -exec sh -c 'ls {}/*.h ...' : Vérifie si le dossier contient au moins un fichier .h
# sed 's/^\./-I /' : Transforme le chemin relatif "./dossier" en drapeau "-I dossier"
# tr '\n' ' ' : Met tous les chemins sur une seule ligne
PROJECT_INCLUDES=$(find . -type d -not -path "./.*" -not -path "./build_cache*" -exec sh -c 'ls {}/*.h >/dev/null 2>&1' \; -print | sed 's/^\./-I /' | tr '\n' ' ')

KERNEL_INCLUDES=""
if [ "$USE_KERNEL" = true ]; then
    if [ -d "$KERNEL_DIR/include" ]; then
        echo "Inclusion Noyau    : ACTIVÉE (Headers trouvés)"
        # On pointe vers les répertoires standards de headers du noyau.
        KERNEL_INCLUDES="-I $KERNEL_DIR/include \
                         -I $KERNEL_DIR/arch/x86/include \
                         -I $KERNEL_DIR/include/uapi \
                         -I $KERNEL_DIR/arch/x86/include/uapi"
    else
        echo "Inclusion Noyau    : ERREUR (Headers introuvables dans $KERNEL_DIR)"
        exit 1
    fi
else
    echo "Inclusion Noyau    : DÉSACTIVÉE (Analyse locale uniquement)"
fi

echo "-------------------------------------------------"
echo "Lancement de l'analyse... (Veuillez patienter)"

# --- Exécution de la commande Cppcheck ---
# Options utilisées :
# --enable=all           : Active Style, Performance, Portabilité, Information et Bugs.
# --inline-suppr         : Autorise les suppressions d'erreurs via // cppcheck-suppress.
# -j $CPU_CORES          : Distribue l'analyse sur tous les coeurs CPU.
# --cppcheck-build-dir   : Active le système de cache incrémental.
# --suppress=missingIncludeSystem : Masque les alertes sur les headers noyau manquants.
# --platform=unix64      : Calibre l'analyse sur des types 64-bits (long, pointeurs).
# -I include             : Répertoire des headers du projet.
# -D...                  : Définit les macros pour simuler la compilation du driver.

cppcheck --enable=all --inline-suppr $USE_FORCE -j $CPU_CORES \
    --cppcheck-build-dir="$CACHE_DIR" \
    --suppress=missingIncludeSystem \
    --platform=unix64 \
    $PROJECT_INCLUDES \
    $KERNEL_INCLUDES \
    -DCONFIG_RTL8821C \
    -DCONFIG_PCI_HCI \
    -D__KERNEL__ \
    -DCONFIG_LITTLE_ENDIAN \
    --output-file=$OUTPUT_FILE \
    .

echo "================================================="
echo "Analyse terminée."
echo "Consultez le fichier : $OUTPUT_FILE"
echo "================================================="
