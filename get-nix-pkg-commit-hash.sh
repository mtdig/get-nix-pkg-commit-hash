#!/usr/bin/env bash

set -euo pipefail

# ── ANSI colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

if [[ $# -ne 2 ]]; then
    echo -e "${BOLD}Usage:${RESET} $0 ${CYAN}<package-name>${RESET} ${CYAN}<version>${RESET}"
    exit 1
fi

PACKAGE="$1"
VERSION="$2"

# First do a quick search if the package exists
echo -e "${BLUE}▸${RESET} Searching for ${BOLD}$PACKAGE${RESET} in nixpkgs..."
SEARCH_JSON=$(nix search nixpkgs "$PACKAGE" --json 2>/dev/null || echo "{}")

# Look for an exact top-level attribute  (legacyPackages.<system>.<package>)
SEARCH_RESULT=$(echo "$SEARCH_JSON" \
    | jq -r --arg pkg "$PACKAGE" \
        'to_entries[]
         | select(.key | test("^legacyPackages\\.[^.]+\\." + $pkg + "$"))
         | "\(.key) (\(.value.version)) — \(.value.description)"')

if [[ -z "$SEARCH_RESULT" ]]; then
    echo -e "${RED}✗${RESET} Package ${BOLD}$PACKAGE${RESET} not found as a top-level attribute in nixpkgs."
    echo ""
    echo -e "${YELLOW}Possible matches:${RESET}"
    echo "$SEARCH_JSON" | jq -r 'to_entries[:10][] | "  \(.key) (\(.value.version))"'
    exit 1
fi

echo -e "${GREEN}✓${RESET} Package found:"
echo -e "  ${BOLD}$SEARCH_RESULT${RESET}"
echo ""

# search for meta.position to find the source file in nixpkgs
echo -e "${BLUE}▸${RESET} Resolving source path for ${BOLD}$PACKAGE${RESET}..."
META_POS=$(nix eval --raw "nixpkgs#${PACKAGE}.meta.position" 2>/dev/null || true)

if [[ -z "$META_POS" ]]; then
    echo -e "${YELLOW}⚠${RESET} Could not resolve meta.position for ${BOLD}$PACKAGE${RESET}."
    echo -e "  ${DIM}Falling back to common path guesses...${RESET}"
    POSSIBLE_PATHS=(
        "pkgs/by-name/${PACKAGE:0:2}/${PACKAGE}/package.nix"
        "pkgs/applications/virtualization/${PACKAGE}/default.nix"
        "pkgs/tools/misc/${PACKAGE}/default.nix"
        "pkgs/development/tools/${PACKAGE}/default.nix"
        "pkgs/applications/misc/${PACKAGE}/default.nix"
        "pkgs/applications/networking/${PACKAGE}/default.nix"
        "pkgs/servers/${PACKAGE}/default.nix"
    )
else
    # meta.position looks like /nix/store/<hash>-source/pkgs/.../default.nix:LINE
    # Strip the store prefix and trailing :LINE
    REL_PATH=$(echo "$META_POS" | sed 's|^.*/pkgs/|pkgs/|; s|:[0-9]*$||')
    echo -e "  ${CYAN}→${RESET} ${DIM}$REL_PATH${RESET}"
    POSSIBLE_PATHS=("$REL_PATH")
fi

echo ""
echo -e "${BLUE}▸${RESET} Searching commit history for version ${BOLD}$VERSION${RESET}..."

FOUND=0
for NIX_PATH in "${POSSIBLE_PATHS[@]}"; do
    RESPONSE=$(curl -s \
        "https://api.github.com/repos/NixOS/nixpkgs/commits?path=${NIX_PATH}&per_page=50")

    # skip if the API returned an error or empty array
    if ! echo "$RESPONSE" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
        continue
    fi

    COMMITS=$(echo "$RESPONSE" \
        | jq -r '.[] | "\(.sha) \(.commit.message | split("\n")[0])"')

    if [[ -z "$COMMITS" ]]; then
        continue
    fi

    FOUND=1
    echo -e "  ${DIM}Commits for path: $NIX_PATH${RESET}"
    MATCH=$(echo "$COMMITS" | grep -i "$VERSION" || true)
    if [[ -n "$MATCH" ]]; then
        echo ""
        echo -e "${GREEN}✓ Found matching commit(s):${RESET}"
        while IFS= read -r line; do
            SHA="${line%% *}"
            MSG="${line#* }"
            echo -e "  ${YELLOW}${SHA:0:12}${RESET} ${BOLD}$MSG${RESET}"
        done <<< "$MATCH"
        exit 0
    else
        echo -e "  ${YELLOW}⚠${RESET} No commit message matched version ${BOLD}$VERSION${RESET} in this path."
        echo -e "  ${DIM}Recent commits:${RESET}"
        echo "$COMMITS" | head -10 | while IFS= read -r line; do
            SHA="${line%% *}"
            MSG="${line#* }"
            echo -e "    ${DIM}${SHA:0:12} $MSG${RESET}"
        done
        echo ""
    fi
done

if [[ "$FOUND" -eq 0 ]]; then
    echo -e "${RED}✗${RESET} No commits found for any candidate path."
    echo -e "  ${DIM}Paths tried:${RESET}"
    printf "    ${DIM}%s${RESET}\n" "${POSSIBLE_PATHS[@]}"
fi

echo ""
echo -e "${RED}✗${RESET} Could not find a commit matching version ${BOLD}$VERSION${RESET}."
echo -e "  ${DIM}The version may not have been merged into nixpkgs yet.${RESET}"
exit 1
