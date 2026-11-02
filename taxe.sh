#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
env_file="$script_dir/.env"
[ ! -f "$env_file" ] || . "$env_file"

url=${URL:-}
delai_secondes=${DELAI_SECONDES:-10}
cout_max_eur=${COUT_MAX_EUR:-1}

[ -n "$url" ] || {
    printf '%s\n' 'URL manquante : copiez .env.example vers .env et renseignez URL.' >&2
    exit 1
}
case $delai_secondes in
    ''|*[!0-9]*) printf '%s\n' 'DELAI_SECONDES doit être un entier positif ou nul.' >&2; exit 1 ;;
esac
LC_ALL=C awk -v valeur="$cout_max_eur" 'BEGIN { exit !(valeur ~ /^[0-9]+([.][0-9]+)?$/) }' || {
    printf '%s\n' 'COUT_MAX_EUR doit être un nombre positif ou nul, avec un point décimal.' >&2
    exit 1
}
if LC_ALL=C awk -v maximum="$cout_max_eur" 'BEGIN { exit !(maximum > 0) }'; then
    curl_version=$(curl --version | LC_ALL=C awk 'NR == 1 {
        split($2, version, ".")
        printf "%d%03d%03d", version[1], version[2], version[3]
    }')
    [ "$curl_version" -ge 8004000 ] || {
        printf '%s\n' 'COUT_MAX_EUR nécessite curl 8.4.0 ou plus récent.' >&2
        exit 1
    }
fi

repertoire=$(mktemp -d "${TMPDIR:-/tmp}/telecharge-pdf.XXXXXX")
fichier="$repertoire/bilan.pdf"

# Nettoie aussi un téléchargement interrompu ou échoué.
trap 'rm -f -- "$fichier"; rmdir -- "$repertoire"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

total=0
tour=0
dernier_octets=0
etat='Prêt'
debut=$(date +%s)

afficher_tableau_de_bord() {
    maintenant=$(date +%s)
    temps_ecoule=$((maintenant - debut))
    [ "$temps_ecoule" -gt 0 ] || temps_ecoule=1
    cadre=$(printf '%60s' '' | tr ' ' '─')
    duree=$(LC_ALL=C awk -v temps="$temps_ecoule" 'BEGIN {
        printf "%02d:%02d:%02d", int(temps / 3600), int(temps % 3600 / 60), temps % 60
    }')
    statistiques=$(LC_ALL=C awk -v total="$total" -v dernier="$dernier_octets" -v temps="$temps_ecoule" 'BEGIN {
        printf "Débit moyen : %.2f Mo/min\n", total / temps * 60 / 1000000
        printf "Dernier fichier : %.2f Mo\n", dernier / 1000000
        printf "Volume total : %.2f Mo", total / 1000000
    }')
    projections=$(LC_ALL=C awk -v total="$total" -v temps="$temps_ecoule" 'BEGIN {
        debit = total / temps
        cout = 0.055 / 1000000000
        printf "Coût brut théorique — 1 h : %.6f €\n", debit * 3600 * cout
        printf "Coût brut théorique — 1 semaine : %.6f €\n", debit * 604800 * cout
        printf "Coût brut théorique — 1 mois : %.6f €\n", debit * 2592000 * cout
        printf "Coût brut théorique — 1 an : %.6f €", debit * 31536000 * cout
    }')
    printf '\033[2J\033[H'
    printf '╭%s\n' "$cadre"
    printf '│ TÉLÉCHARGEMENT EN CONTINU\n'
    printf '├%s\n' "$cadre"
    printf '│ État : %s\n' "$etat"
    printf '│ Téléchargements terminés : %s\n' "$tour"
    printf '│ Temps écoulé : %s\n' "$duree"
    printf '%s\n' "$statistiques" | while IFS= read -r ligne || [ -n "$ligne" ]; do
        printf '│ %s\n' "$ligne"
    done
    printf '├%s\n' "$cadre"
    printf '│ PROJECTIONS AU DÉBIT ACTUEL\n'
    printf '%s\n' "$projections" | while IFS= read -r ligne || [ -n "$ligne" ]; do
        printf '│ %s\n' "$ligne"
    done
    printf '├%s\n' "$cadre"
    printf '│ Ctrl+C pour arrêter proprement.\n'
    printf '╰%s\n' "$cadre"
}

afficher_tableau_de_bord
while :; do
    etat='Téléchargement en cours…'
    afficher_tableau_de_bord
    limite_fichier=''
    if LC_ALL=C awk -v maximum="$cout_max_eur" 'BEGIN { exit !(maximum > 0) }'; then
        octets_restants=$(LC_ALL=C awk -v total="$total" -v maximum="$cout_max_eur" 'BEGIN {
            printf "%.0f", maximum / 0.055 * 1000000000 - total
        }')
        if [ "$octets_restants" -le 0 ]; then
            etat='Plafond de coût atteint'
            afficher_tableau_de_bord
            exit 0
        fi
        limite_fichier=$octets_restants
    fi
    set -- --globoff --fail --location --silent --show-error \
        --connect-timeout 15 --max-time 120
    [ -z "$limite_fichier" ] || set -- "$@" --max-filesize "$limite_fichier"
    set -- "$@" --output "$fichier" --write-out '%{size_download}' "$url"
    if octets=$(curl "$@"); then
        :
    else
        curl_status=$?
        case $octets in
            ''|*[!0-9]*) octets=0 ;;
        esac
        total=$((total + octets))
        dernier_octets=$octets
        if [ "$curl_status" -eq 63 ] && [ -n "$limite_fichier" ]; then
            etat='Budget restant inférieur à la taille du fichier'
            afficher_tableau_de_bord
            exit 0
        fi
        etat="Téléchargement interrompu (curl $curl_status)"
        afficher_tableau_de_bord
        exit "$curl_status"
    fi
    rm -f -- "$fichier"
    total=$((total + octets))
    tour=$((tour + 1))
    dernier_octets=$octets
    etat='Cycle terminé — nouveau téléchargement imminent'
    afficher_tableau_de_bord
    if LC_ALL=C awk -v total="$total" -v maximum="$cout_max_eur" 'BEGIN {
        exit !(maximum > 0 && total / 1000000000 * 0.055 >= maximum)
    }'; then
        etat='Plafond de coût atteint'
        afficher_tableau_de_bord
        exit 0
    fi
    [ "$delai_secondes" -eq 0 ] || sleep "$delai_secondes"
done
