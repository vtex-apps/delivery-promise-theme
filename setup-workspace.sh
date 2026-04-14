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
  read -rp "Enter workspace name (lowercase letters only): " myworkspace
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

# ── 5. Uninstall all apps whose vendor matches the account ───────────
echo "Listing installed apps..."
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

# ── 6. Edit manifest.json vendor ─────────────────────────────────────
manifest="./manifest.json"
if [[ ! -f "$manifest" ]]; then
  echo "Error: $manifest not found in current directory."
  exit 1
fi

echo "Updating vendor in manifest.json to '$account'..."
tmp=$(mktemp)
jq --arg acct "$account" '.vendor = $acct' "$manifest" > "$tmp" && mv "$tmp" "$manifest"

# ── 7. Link the app ─────────────────────────────────────────────────
echo "Linking app (no-watch)..."
vtex link --no-watch

# ── 8. PUT store/routes.json on vbase (pages-graphql userData) ──────
echo "Updating store/routes.json on vbase..."
token=$(vtex local token | tr -d '\r')
if [[ -z "$token" ]]; then
  echo "Error: 'vtex local token' returned empty output."
  exit 1
fi
vbase_url="http://vbase.aws-us-east-1.vtex.io/${account}/${myworkspace}/buckets/vtex.pages-graphql/userData/files/store/routes.json"
curl --location --request PUT "$vbase_url" \
  --header "VtexIdclientAutCookie: ${token}"

# ── 9. Open workspace in browser ────────────────────────────────────
echo "Opening workspace in browser..."
vtex browse

echo "Done!"
