# Regionalization theme

This store theme exists to **exercise and validate [delivery-promise-components](https://github.com/vtex-apps/delivery-promise-components)** (`vtex.delivery-promise-components`) in a real Store Framework setup.

**Account requirement:** it is only expected to work in VTEX accounts where **delivery promise components** are **enabled** (and any related platform capabilities your team uses for delivery promises). On accounts without that support, blocks and APIs this theme relies on may be missing or behave differently.

---

## `setup-workspace.sh`

Helper script in the **repository root** (same folder as `manifest.json`) to prepare a **non-`master`** development workspace and link this theme.

### Prerequisites

- [VTEX IO CLI](https://developers.vtex.com/docs/guides/vtex-io-documentation-vtex-io-cli-installation-and-command-reference) installed and logged in (`vtex login`).
- [`jq`](https://jqlang.org/) installed (used to set `vendor` in `manifest.json`).
- Run the script from the theme root so `./manifest.json` is found.

### How to run

```bash
cd /path/to/regionalization-theme
chmod +x ./setup-workspace.sh   # once
./setup-workspace.sh
```

The script will:

1. Read the account from `vtex whoami` and ask you to confirm before continuing.
2. Ask for a **workspace name** (lowercase letters only; **`master` is not allowed**).
3. Run `vtex workspace use <name>`, answering **yes** if the CLI offers to create the workspace.
4. Warn that the workspace will be **reset** and ask for your **explicit permission**; if you agree, it runs `vtex workspace reset` (and confirms the CLI prompt).
5. Install `vtex.search-session@0.x`.
6. Run `vtex ls` and **uninstall** every app whose **vendor equals your account** (confirming each uninstall prompt).
7. Set `manifest.json` **`vendor`** to the detected account name.
8. Run `vtex link --no-watch`.
9. Run `vtex browse` to open the workspace in the browser.
10. `PUT` `store/routes.json` on vbase for Pages GraphQL user data, using `vtex local token` as `VtexIdclientAutCookie`.

If any step fails (empty token, missing `manifest.json`, etc.), the script exits with an error message.
