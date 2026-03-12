#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════
# ProfiSan — Deployment (wiederverwendbar)
# ═══════════════════════════════════════════════════════
#
# Nutzung:
#   ./deploy.sh              → Theme + Plugins + DB-Inhalte
#   ./deploy.sh theme        → Nur Theme-Dateien
#   ./deploy.sh plugins      → Nur Plugins
#   ./deploy.sh content      → Nur DB-Inhalte (Seiten + Optionen)
#   ./deploy.sh files        → Nur Theme + Plugins (ohne DB)
#
# Voraussetzungen: lftp, studio CLI
#

# ── Konfiguration ─────────────────────────────────────
FTP_HOST=""
FTP_USER=""
FTP_PASS=""
FTP_PORT="21"
FTP_WP_PATH="/htdocs"                     # WordPress-Root auf dem FTP-Server
DOMAIN="https://www.profisan-gmbh.de"

LOCAL_WP_PATH="$HOME/Studio/profisan-gmbh"
STUDIO_WP="studio wp --path=$LOCAL_WP_PATH"
# ──────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
THEME_DIR="$SCRIPT_DIR/.."
TARGET="${1:-all}"
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

for CMD in lftp git; do
  command -v "$CMD" &>/dev/null || { echo "FEHLER: $CMD nicht installiert."; exit 1; }
done

if [ -z "$FTP_HOST" ]; then
  echo "FEHLER: FTP_HOST muss konfiguriert sein."
  exit 1
fi

LFTP="lftp -u $FTP_USER,$FTP_PASS -p $FTP_PORT $FTP_HOST"

echo "══════════════════════════════════════"
echo " ProfiSan — Deploy ($TARGET)"
echo "══════════════════════════════════════"

# ── Theme deployen ──
deploy_theme() {
  echo ""
  echo "→ Theme deployen..."
  cd "$THEME_DIR"
  if ! git diff --quiet HEAD 2>/dev/null; then
    echo "  WARNUNG: Uncommitted changes! Bitte zuerst committen."
    exit 1
  fi
  git push 2>/dev/null || true

  $LFTP <<EOF
mirror -R --delete --exclude .git/ --exclude deploy/ --exclude .DS_Store \
  "$THEME_DIR" "$FTP_WP_PATH/wp-content/themes/profisan-theme"
quit
EOF
  echo "  OK"
}

# ── Plugins deployen ──
deploy_plugins() {
  echo ""
  echo "→ Plugins deployen..."
  git clone --depth 1 https://github.com/roscha444/wp-plugins.git "$TMP_DIR/plugins" 2>/dev/null
  for PLUGIN in srk-security srk-contact-forms srk-smtp-mailer; do
    echo "  $PLUGIN..."
    $LFTP <<EOF
mirror -R --delete --exclude .git/ --exclude .DS_Store \
  "$TMP_DIR/plugins/$PLUGIN" "$FTP_WP_PATH/wp-content/plugins/$PLUGIN"
quit
EOF
  done
  echo "  OK"
}

# ── DB-Inhalte deployen ──
deploy_content() {
  echo ""
  echo "→ Lokale DB exportieren..."

  # Seiten exportieren
  $STUDIO_WP eval '
  $pages = get_pages(["post_status" => "publish"]);
  $export = [];
  foreach ($pages as $p) {
      $export[] = [
          "slug"    => $p->post_name,
          "title"   => $p->post_title,
          "content" => $p->post_content,
      ];
  }
  echo json_encode($export, JSON_UNESCAPED_UNICODE);
  ' 2>/dev/null > "$TMP_DIR/pages.json"

  # Optionen exportieren
  $STUDIO_WP eval '
  $opts = [
      "srk_cf_forms"             => get_option("srk_cf_forms", []),
      "srk_cf_options"           => get_option("srk_cf_options", []),
      "profisan_maintenance_mode"=> get_option("profisan_maintenance_mode", false),
      "srk_sec_csp_enabled"      => get_option("srk_sec_csp_enabled", true),
      "srk_sec_csp_whitelist"    => get_option("srk_sec_csp_whitelist", ""),
      "srk_sec_upgrade_insecure" => get_option("srk_sec_upgrade_insecure", true),
      "blogname"                 => get_option("blogname"),
      "blogdescription"          => get_option("blogdescription"),
  ];
  echo json_encode($opts, JSON_UNESCAPED_UNICODE);
  ' 2>/dev/null > "$TMP_DIR/options.json"

  PAGES_COUNT=$(python3 -c "import json; print(len(json.load(open('$TMP_DIR/pages.json'))))")
  echo "  $PAGES_COUNT Seiten exportiert"

  # Sync-Script generieren
  SYNC_TOKEN=$(openssl rand -hex 32)
  PAGES_B64=$(base64 < "$TMP_DIR/pages.json")
  OPTIONS_B64=$(base64 < "$TMP_DIR/options.json")

  cat > "$TMP_DIR/srk-sync.php" <<PHPEOF
<?php
if ( ! isset( \$_GET['token'] ) || \$_GET['token'] !== '$SYNC_TOKEN' ) {
    http_response_code( 403 );
    exit( 'Forbidden' );
}

define( 'ABSPATH', __DIR__ . '/' );
define( 'WPINC', 'wp-includes' );
require_once ABSPATH . 'wp-load.php';

\$results = [];

// Seiten synchronisieren
\$pages = json_decode( base64_decode( '$PAGES_B64' ), true );
foreach ( \$pages as \$page ) {
    \$existing = get_page_by_path( \$page['slug'] );
    if ( \$existing ) {
        wp_update_post( [
            'ID'           => \$existing->ID,
            'post_title'   => \$page['title'],
            'post_content' => \$page['content'],
            'post_status'  => 'publish',
        ] );
        \$results[] = "'{$page['title']}' aktualisiert";
    } else {
        wp_insert_post( [
            'post_title'   => \$page['title'],
            'post_name'    => \$page['slug'],
            'post_content' => \$page['content'],
            'post_status'  => 'publish',
            'post_type'    => 'page',
        ] );
        \$results[] = "'{$page['title']}' angelegt";
    }
}

// Optionen synchronisieren
\$options = json_decode( base64_decode( '$OPTIONS_B64' ), true );
foreach ( \$options as \$key => \$value ) {
    update_option( \$key, \$value );
}
\$results[] = count( \$options ) . ' Optionen synchronisiert';

@unlink( __FILE__ );
\$results[] = 'Sync-Script gelöscht';

header( 'Content-Type: text/plain; charset=utf-8' );
echo implode( "\\n", \$results ) . "\\n";
PHPEOF

  echo "→ DB auf Server synchronisieren..."
  $LFTP <<EOF
put "$TMP_DIR/srk-sync.php" -o "$FTP_WP_PATH/srk-sync.php"
quit
EOF

  RESULT=$(curl -sf "$DOMAIN/srk-sync.php?token=$SYNC_TOKEN" 2>&1) || {
    echo "  FEHLER: Sync-Script konnte nicht ausgeführt werden."
    echo "  Lösche srk-sync.php manuell vom Server!"
    exit 1
  }
  echo "$RESULT" | sed 's/^/  /'
}

# ── Ausführen ──
case "$TARGET" in
  theme)   deploy_theme ;;
  plugins) deploy_plugins ;;
  content) deploy_content ;;
  files)   deploy_theme; deploy_plugins ;;
  all)     deploy_theme; deploy_plugins; deploy_content ;;
  *)
    echo "Unbekannter Befehl: $TARGET"
    echo "Nutzung: ./deploy.sh [theme|plugins|content|files|all]"
    exit 1
    ;;
esac

echo ""
echo "Deployment abgeschlossen."
echo ""
