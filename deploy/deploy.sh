#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════
# ProfiSan — Deployment (wiederverwendbar)
# ═══════════════════════════════════════════════════════
#
# Nutzung:
#   ./deploy.sh              → Theme + Plugins deployen
#   ./deploy.sh theme        → Nur Theme
#   ./deploy.sh plugins      → Nur Plugins
#   ./deploy.sh cache        → Nur Cache leeren
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

SSH="ssh -p $SSH_PORT $SSH_HOST"
REMOTE_THEME="$WP_PATH/wp-content/themes/profisan-theme"
REMOTE_PLUGINS="$WP_PATH/wp-content/plugins"
TARGET="${1:-all}"

echo "══════════════════════════════════════"
echo " ProfiSan — Deploy ($TARGET)"
echo "══════════════════════════════════════"

# ── Theme deployen ──
deploy_theme() {
  echo ""
  echo "→ Theme deployen..."

  # Lokale Änderungen committen?
  cd "$SCRIPT_DIR/.."
  if ! git diff --quiet HEAD 2>/dev/null; then
    echo "  WARNUNG: Uncommitted changes im Theme!"
    echo "  Bitte zuerst committen und pushen."
    exit 1
  fi

  # Lokalen Branch pushen
  echo "  Lokale Änderungen pushen..."
  git push

  # Auf Server pullen
  $SSH "cd '$REMOTE_THEME' && git pull"
  echo "  Theme aktualisiert"
}

# ── Plugins deployen ──
deploy_plugins() {
  echo ""
  echo "→ Plugins deployen..."

  $SSH "
    TMP_DIR=\$(mktemp -d)
    git clone --depth 1 '$PLUGINS_REPO' \"\$TMP_DIR\" 2>/dev/null

    for PLUGIN in srk-security srk-contact-forms srk-smtp-mailer; do
      if [ -d \"\$TMP_DIR/\$PLUGIN\" ]; then
        rm -rf '$REMOTE_PLUGINS/'\$PLUGIN
        cp -R \"\$TMP_DIR/\$PLUGIN\" '$REMOTE_PLUGINS/'\$PLUGIN
        echo \"  \$PLUGIN aktualisiert\"
      fi
    done

    rm -rf \"\$TMP_DIR\"
  "
}

# ── Cache leeren ──
flush_cache() {
  echo ""
  echo "→ Cache leeren..."
  $SSH "cd '$WP_PATH' && $WP_CLI cache flush && $WP_CLI rewrite flush" 2>/dev/null || true
  echo "  Cache geleert"
}

# ── Ausführen ──
case "$TARGET" in
  theme)
    deploy_theme
    flush_cache
    ;;
  plugins)
    deploy_plugins
    flush_cache
    ;;
  cache)
    flush_cache
    ;;
  all)
    deploy_theme
    deploy_plugins
    flush_cache
    ;;
  *)
    echo "Unbekannter Befehl: $TARGET"
    echo "Nutzung: ./deploy.sh [theme|plugins|cache|all]"
    exit 1
    ;;
esac

echo ""
echo "Deployment abgeschlossen."
echo ""
