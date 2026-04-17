#!/bin/bash
set -euo pipefail

# ── 1. Detect account ────────────────────────────────────────────────
whoami_output=$(vtex whoami 2>&1)
account=$(echo "$whoami_output" | sed -n 's/.*Logged into \([^ ]*\) .*/\1/p')

if [[ -z "$account" ]]; then
  echo "Error: could not determine the account name from 'vtex whoami'."
  echo "Output was: $whoami_output"
  exit 1
fi

echo "Current account: $account"
read -rp "Proceed with this account? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

# ── 2. Ask for workspace name (lowercase letters only, never master) ─
while true; do
  read -rp "Enter workspace name (lowercase letters only; press Enter for 'dptest'): " myworkspace
  myworkspace="${myworkspace:-dptest}"
  if [[ ! "$myworkspace" =~ ^[a-z]+$ ]]; then
    echo "Invalid: workspace name must contain only lowercase letters."
    continue
  fi
  if [[ "$myworkspace" == "master" ]]; then
    echo "Invalid: workspace 'master' is not allowed. Use a different name."
    continue
  fi
  break
done

# ── 3. Switch to the workspace (auto-confirm creation) ───────────────
echo "Switching to workspace '$myworkspace'..."
echo "Y" | vtex workspace use "$myworkspace"

echo ""
echo "Next step: reset workspace '$myworkspace'. That clears apps and configuration from this workspace so setup starts clean."
read -rp "Allow resetting this workspace? (y/N): " reset_confirm
if [[ "$reset_confirm" != "y" && "$reset_confirm" != "Y" ]]; then
  echo "Aborted (workspace reset was not confirmed)."
  exit 0
fi
echo "Resetting workspace '$myworkspace'..."
echo "y" | vtex workspace reset

# ── 4. Install search-session ────────────────────────────────────────
echo "Installing vtex.search-session@0.x..."
vtex install vtex.search-session@0.x

# ── 5. Edit manifest.json vendor ─────────────────────────────────────
# manifest="./manifest.json"
# if [[ ! -f "$manifest" ]]; then
#   echo "Error: $manifest not found in current directory."
#   exit 1
# fi

# echo "Updating vendor in manifest.json to '$account'..."
# tmp=$(mktemp)
# jq --arg acct "$account" '.vendor = $acct' "$manifest" > "$tmp" && mv "$tmp" "$manifest"

# ── 6. Header layout: case1 / case2 / case3 (desktop & mobile) ───────
header_jsonc="./store/blocks/header/header.jsonc"
if [[ ! -f "$header_jsonc" ]]; then
  echo "Error: $header_jsonc not found in current directory."
  exit 1
fi

echo ""
echo "Choose header layout (delivery-promise-components; updates desktop and mobile):"
echo "  1) shopper-location-setter only (case1)"
echo "  2) shopper-location-setter + pickup-point-selector (case2)"
echo "  3) shopper-location-setter + shipping-method-selector (case3)"
while true; do
  read -rp "Enter choice [1-3]: " layout_choice
  case "$layout_choice" in
    1 | 2 | 3) break ;;
    *) echo "Invalid: enter 1, 2, or 3." ;;
  esac
done

tmp_header=$(mktemp)
jq --arg c "$layout_choice" \
  '.["sticky-layout#4-desktop"].children[0] = ("flex-layout.row#4-desktop-case" + $c)
   | .["sticky-layout#1-mobile"].children[0] = ("flex-layout.row#1-mobile-case" + $c)' \
  "$header_jsonc" > "$tmp_header" && mv "$tmp_header" "$header_jsonc"
echo "Updated header.jsonc to use case${layout_choice} (sticky rows)."

# ── 7. Link the app ─────────────────────────────────────────────────
echo "Linking app (no-watch)..."
vtex link --no-watch

# ── 8. Uninstall all apps whose vendor matches the account ───────────
vtex ls 2>&1 | while IFS= read -r line; do
  app_id=$(echo "$line" | awk '{print $1}')
  vendor=$(echo "$app_id" | cut -d'.' -f1)

  if [[ "$vendor" == "$account" ]]; then
    version=$(echo "$line" | awk '{print $2}')
    full="$app_id@$version"
    echo "Uninstalling $full ..."
    echo "y" | vtex uninstall "$full" || true
  fi
done

# ── 9. PUT store/routes.json on vbase (pages-graphql userData) ──────
echo "Updating store/routes.json on vbase..."
token=$(vtex local token | tr -d '\r')
if [[ -z "$token" ]]; then
  echo "Error: 'vtex local token' returned empty output."
  exit 1
fi
vbase_url="http://vbase.aws-us-east-1.vtex.io/${account}/${myworkspace}/buckets/vtex.pages-graphql/userData/files/store/routes.json"
curl --location --request PUT "$vbase_url" \
  --header "VtexIdclientAutCookie: ${token}"

# ── 10. Open workspace in browser ────────────────────────────────────
echo "Opening workspace in browser..."
vtex browse

echo "Done!"
