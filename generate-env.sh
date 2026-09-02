#!/bin/sh
# Copyright © 2026 Gornskew Enterprises
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.  Distributed WITHOUT
# ANY WARRANTY; see <https://www.gnu.org/licenses/agpl-3.0.html>.

# Generate .env file for docker-compose

set -e

echo "Generating .env file for docker-compose..."

USER_HOME="${USER_HOME:-$HOME}"

HOST_USER_UID=$(id -u)
DOCKER_GROUP_ID=$(getent group docker 2>/dev/null | cut -d: -f3 || echo 999)
# Honor a pre-set CURRENT_BRANCH (e.g. exported by compose-dev standalone
# bootstrap, which knows which image branch supplied this script); otherwise
# detect from git, falling back to master.
CURRENT_BRANCH="${CURRENT_BRANCH:-$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo master)}"
PROJECTS_DIR="${PROJECTS_DIR:-$USER_HOME/projects}"

# Per-host image variant pin (lite/default/tui/gui/full).  Precedence:
# pre-set env (e.g. from a stack repo's systemd unit Environment= line,
# or a compose-dev --lite/--default/... switch) > existing .env pin
# (so regeneration never silently un-pins a host) > unset (compose
# falls back to full).
if [ -z "${EMACS_IMAGE_VARIANT:-}" ] && [ -f .env ]; then
    EMACS_IMAGE_VARIANT="$(sed -n 's/^EMACS_IMAGE_VARIANT=//p' .env | head -1)"
fi
EMACS_VARIANT_LINE=""
if [ -n "${EMACS_IMAGE_VARIANT:-}" ]; then
    EMACS_VARIANT_LINE="EMACS_IMAGE_VARIANT=$EMACS_IMAGE_VARIANT"
    echo "Pinning skewed-emacs image variant: $EMACS_IMAGE_VARIANT"
fi

# Detect host timezone (best-effort across Linux and macOS)
HOST_TZ=$(
    timedatectl show -p Timezone --value 2>/dev/null || \
    cat /etc/timezone 2>/dev/null || \
    systemsetup -gettimezone 2>/dev/null | awk '{print $NF}' || \
    echo "Etc/UTC"
)

# Optional: mount ~/.emacs-local if it exists
EMACS_LOCAL_LINE=""
if [ -f "$USER_HOME/.emacs-local" ]; then
    EMACS_LOCAL_LINE="EMACS_LOCAL_SRC=$USER_HOME"
fi

# =============================================================================
# N INSTANCES ON ONE HOST
#
# Set BASILISK_INSTANCE to run more than one stack on the same box.  It is
# empty by default, which reproduces the historical single-stack settings
# -- container names unprefixed and every published port on its original
# number.
#
#   BASILISK_INSTANCE=alpha BASILISK_PORT_OFFSET=100 ./basilisk up
#
# Three things have to differ between instances and they differ here rather
# than in any generated YAML:
#
#   container names  -- GLOBAL to the docker daemon, so this is the one true
#                       collision.  BASILISK_PREFIX handles it (prefixing the
#                       minted crew names).  In-network hostnames stay
#                       canonical, so every ship's rooms answer to their
#                       plain type slugs (ready-room, bridge) on his own
#                       network.
#   network name     -- one bridge per instance, or they share a broadcast
#                       domain and service DNS becomes ambiguous.  Each
#                       instance is his own SHIP and carries his own minted
#                       name (basilisks are said to be all male); see THE
#                       SHIP'S NAME below.
#   published ports  -- a host port can only be claimed once.
#
# The offset is applied here, in shell, because compose cannot do arithmetic
# in a variable expansion.  Pick an offset that keeps ports clear of the
# defaults: 100 gives 7042/19180/29180/9198/19169/19291/9188.
# =============================================================================
BASILISK_INSTANCE="${BASILISK_INSTANCE:-}"
BASILISK_PORT_OFFSET="${BASILISK_PORT_OFFSET:-0}"

if [ -n "$BASILISK_INSTANCE" ]; then
    BASILISK_PREFIX="${BASILISK_INSTANCE}-"
else
    BASILISK_PREFIX=""
fi

# =============================================================================
# THE SHIP'S NAME (2026-08-17; mortality ruled 2026-08-24)
#
# THE YARD names each ship at his raising, and he keeps that name for
# life -- and a life is ONE COMMISSION: every full `up` raises a NEW
# ship under a fresh name, and the one before him is buried in the
# log of ships (.ships-log).  The current ship's name rides in .ship
# (per instance: .ship-<instance>), beside .env and equally
# uncommitted.  The docker network IS the ship: the connective tissue
# every crew member plugs into.  So the network takes the ship's
# name, unique per galaxy (host) among the living AND the buried --
# minting retries against the names docker knows and the log
# remembers.  An inherited BASILISK_SHIP (environment or systemd
# host.env) wins over minting entirely, same precedence as every
# other pin here, for a rig that wants one name held.
#
# The generated compose still falls back to "basilisk" (the class
# name) when DOCKER_NETWORK_NAME is absent, so a ship fitted out by
# hand before naming still sails.  NOTE: on an existing deployment the first
# regeneration after this change renames the network, and the next
# `up' is therefore a relief in place -- compose recreates the crew
# onto the renamed ship.
# =============================================================================
_ship_pick() {
    set -- $1
    _sp_n=$#
    _sp_r=$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')
    _sp_i=$(( (_sp_r % _sp_n) + 1 ))
    eval "echo \${$_sp_i}"
}

_mint_ship_name() {
    # Basilisk-flavored, serpent under the bow: Vorilisk, Skalyss,
    # Zhurorath, Thessek ...  A name is never re-minted: the living
    # (docker's networks) and the buried (the log of ships) both
    # count as taken -- history stays unambiguous, and the famous
    # names stay their bearers' own.
    _ms_onsets='Bas Vor Skal Zhur Thess Karn Ssyr Drax Vy Or'
    _ms_finals='ilisk yss orath ura ek onn ith esk ala und'
    _ms_known="$( { docker network ls --format '{{.Name}}' 2>/dev/null; \
                    cut -f1 "$SHIPS_LOG" 2>/dev/null; } | tr 'A-Z' 'a-z')"
    _ms_tries=0
    while :; do
        _ms_name="$(_ship_pick "$_ms_onsets")$(_ship_pick "$_ms_finals")"
        _ms_lower="$(printf '%s' "$_ms_name" | tr 'A-Z' 'a-z')"
        if printf '%s\n' "$_ms_known" | grep -qxF "$_ms_lower"; then
            _ms_tries=$((_ms_tries + 1))
            if [ $_ms_tries -ge 20 ]; then
                _ms_name="${_ms_name}-$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')"
                break
            fi
        else
            break
        fi
    done
    echo "$_ms_name"
}

SHIP_FILE=".ship${BASILISK_INSTANCE:+-$BASILISK_INSTANCE}"
SHIPS_LOG=".ships-log"

# A fork's register vocabulary (generated from its glossary).  This
# script announces the minting and the burial, so it reads the
# dictionary the same way compose-dev does; canon ships no glossary
# and every default below stands.
[ -f "generated/vocabulary.env" ] && . "generated/vocabulary.env"
if [ -n "${BASILISK_SHIP:-}" ]; then
    :  # inherited pin wins; do not re-mint or overwrite the log entry
elif [ -f "$SHIP_FILE" ] && [ -z "${BASILISK_MINT_FRESH:-}" ]; then
    BASILISK_SHIP="$(head -1 "$SHIP_FILE")"
else
    # A NEW SHIP AT EVERY RAISING (ruling 2026-08-24): a full `up`
    # exports BASILISK_MINT_FRESH=1 and a fresh name is minted here.
    # The outgoing ship is buried under his own name in the log of
    # ships: his working logs died with his containers, but the name
    # and his dates are kept -- some names go down famous.
    if [ -f "$SHIP_FILE" ]; then
        _old_ship="$(head -1 "$SHIP_FILE")"
        _raised_epoch="$(stat -c %Y "$SHIP_FILE" 2>/dev/null \
            || stat -f %m "$SHIP_FILE" 2>/dev/null || echo '')"
        _raised="$( [ -n "$_raised_epoch" ] && \
            ( date -d "@$_raised_epoch" +%Y-%m-%d 2>/dev/null \
              || date -r "$_raised_epoch" +%Y-%m-%d 2>/dev/null ) \
            || echo unknown )"
        printf '%s\traised %s\tburied %s%s\n' \
            "$_old_ship" "$_raised" "$(date +%Y-%m-%dT%H:%M)" \
            "${BASILISK_INSTANCE:+	instance $BASILISK_INSTANCE}" >> "$SHIPS_LOG"
        # shellcheck disable=SC2059  (vocab values are printf formats)
        printf "${BASILISK_VOCAB_SHIP_BURIED:-The ship %s is buried in the log of ships (%s)}\n" \
            "$_old_ship" "$SHIPS_LOG"
    fi
    BASILISK_SHIP="$(_mint_ship_name)"
    printf '%s\n' "$BASILISK_SHIP" > "$SHIP_FILE"
    # shellcheck disable=SC2059  (vocab values are printf formats)
    printf "${BASILISK_VOCAB_SHIP_MINTED:-Minted ship's name: %s (kept in %s)}\n" \
        "$BASILISK_SHIP" "$SHIP_FILE"
fi
NETWORK_NAME="$(printf '%s' "$BASILISK_SHIP" | tr 'A-Z' 'a-z')"

_off() { echo $(( $1 + BASILISK_PORT_OFFSET )); }

cat > .env << EOF
# Docker Compose Environment Variables
# Generated by ./generate-env.sh

# User paths
USER_HOME=$USER_HOME
PROJECTS_DIR=$PROJECTS_DIR

# User/Group IDs
HOST_USER_UID=$HOST_USER_UID
DOCKER_GROUP_ID=$DOCKER_GROUP_ID

# Image and Container names
CURRENT_BRANCH=$CURRENT_BRANCH
EMACS_IMAGE_BRANCH=$CURRENT_BRANCH
EMACS_IMAGE_BASE=readymax
$EMACS_VARIANT_LINE
GENDL_IMAGE_BRANCH=$CURRENT_BRANCH
GENDL_IMAGE_BASE=gendl

# Instance identity (empty = the historical single-stack behaviour)
BASILISK_INSTANCE=$BASILISK_INSTANCE
BASILISK_PREFIX=$BASILISK_PREFIX
BASILISK_PORT_OFFSET=$BASILISK_PORT_OFFSET

# The ship: his minted name, and the network that IS him (one bridge
# per instance, named for the ship)
BASILISK_SHIP=$BASILISK_SHIP
DOCKER_NETWORK_NAME=$NETWORK_NAME

# Published host ports, offset by BASILISK_PORT_OFFSET.  An inherited
# value wins, same precedence as EMACS_IMAGE_VARIANT above, because
# these defaults are DEV ports: a ship whose Transporter Chief fronts
# the public internet publishes :80, and regenerating .env must not
# quietly move it to 19069 and take the site off the air.  Host pins ride in
# systemd/host.env, which ./basilisk exports before calling this.
TTYD_HOST_PORT=${TTYD_HOST_PORT:-$(_off 6942)}
GENDL_CCL_HOST_PORT=${GENDL_CCL_HOST_PORT:-$(_off 19080)}
GENDL_SBCL_HOST_PORT=${GENDL_SBCL_HOST_PORT:-$(_off 29080)}
CYCLOPS_HOST_PORT=${CYCLOPS_HOST_PORT:-$(_off 19069)}
CYCLOPS_UTILITY_HOST_PORT=${CYCLOPS_UTILITY_HOST_PORT:-$(_off 19191)}
GDL_SMP_HOST_PORT=${GDL_SMP_HOST_PORT:-$(_off 9098)}
GDL_NON_SMP_HOST_PORT=${GDL_NON_SMP_HOST_PORT:-$(_off 9088)}

TERM=xterm-256color
COLORTERM=truecolor

$EMACS_LOCAL_LINE

# Timezone (detected from host)
TZ=$HOST_TZ

EOF

echo ""
echo ".env file has the following settings:"
echo "CURRENT_BRANCH: $CURRENT_BRANCH"
echo "PROJECTS_DIR:   $PROJECTS_DIR"
echo "HOST_USER_UID:  $HOST_USER_UID"
echo ""
