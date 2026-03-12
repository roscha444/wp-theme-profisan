#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════
# ProfiSan — Einmal-Migration auf den Server
# ═══════════════════════════════════════════════════════
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
echo " ProfiSan — Server-Setup"
echo "══════════════════════════════════════"
echo ""
echo "FTP:    $FTP_USER@$FTP_HOST"
echo "Lokal:  $LOCAL_WP_PATH"
echo "Domain: $DOMAIN"
echo ""
read -p "Fortfahren? (j/n) " -n 1 -r
echo
[[ $REPLY =~ ^[Jj]$ ]] || exit 1

# ── 1. Theme hochladen ──
echo ""
echo "→ Theme hochladen..."
$LFTP <<EOF
mirror -R --delete --exclude .git/ --exclude deploy/ --exclude .DS_Store \
  "$THEME_DIR" "$FTP_WP_PATH/wp-content/themes/profisan-theme"
quit
EOF
echo "  OK"

# ── 2. Plugins hochladen ──
echo "→ Plugins hochladen..."
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

# ── 3. Sicherheits-Cleanup ──
echo "→ Sicherheits-Cleanup..."
$LFTP <<EOF
rm -f "$FTP_WP_PATH/readme.html" 2>/dev/null
rm -f "$FTP_WP_PATH/license.txt" 2>/dev/null
rm -f "$FTP_WP_PATH/wp-config-sample.php" 2>/dev/null
rm -rf "$FTP_WP_PATH/wp-content/themes/twentytwentythree" 2>/dev/null
rm -rf "$FTP_WP_PATH/wp-content/themes/twentytwentyfour" 2>/dev/null
rm -rf "$FTP_WP_PATH/wp-content/themes/twentytwentyfive" 2>/dev/null
quit
EOF
echo "  OK"

# ── 4. Lokale DB exportieren ──
echo "→ Lokale Datenbank exportieren..."

# Seiteninhalte exportieren
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

# Plugin-Optionen exportieren
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

# ── 5. Setup-Script generieren (nur Logik, keine Daten) ──
echo "→ Setup-Script generieren..."
SETUP_TOKEN=$(openssl rand -hex 32)

cat > "$TMP_DIR/srk-setup.php" <<'PHPEOF'
<?php
// Einmal-Setup — löscht sich nach Ausführung selbst.
// Daten kommen ausschließlich per POST-Body (kein Dateisystem).
$headers = getallheaders();
if ( ! isset( $headers['X-Setup-Token'] ) || $headers['X-Setup-Token'] !== '%%TOKEN%%' ) {
    http_response_code( 403 );
    exit( 'Forbidden' );
}
if ( $_SERVER['REQUEST_METHOD'] !== 'POST' ) {
    http_response_code( 405 );
    exit( 'POST required' );
}

$payload = json_decode( file_get_contents( 'php://input' ), true );
if ( ! $payload || ! isset( $payload['pages'], $payload['options'] ) ) {
    http_response_code( 400 );
    exit( 'Invalid payload' );
}

define( 'ABSPATH', __DIR__ . '/' );
define( 'WPINC', 'wp-includes' );
require_once ABSPATH . 'wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';

$results = [];

// Theme aktivieren
switch_theme( 'profisan-theme' );
$results[] = 'Theme aktiviert';

// Plugins aktivieren
foreach ( ['srk-security/srk-security.php', 'srk-contact-forms/srk-contact-forms.php', 'srk-smtp-mailer/srk-smtp-mailer.php'] as $p ) {
    if ( ! is_plugin_active( $p ) ) { activate_plugin( $p ); }
}
$results[] = 'Plugins aktiviert';

// Seiten importieren
foreach ( $payload['pages'] as $page ) {
    $existing = get_page_by_path( $page['slug'] );
    if ( $existing ) {
        wp_update_post( [
            'ID'           => $existing->ID,
            'post_title'   => $page['title'],
            'post_content' => $page['content'],
            'post_status'  => 'publish',
        ] );
        $results[] = "Seite '{$page['title']}' aktualisiert (ID: {$existing->ID})";
    } else {
        $id = wp_insert_post( [
            'post_title'   => $page['title'],
            'post_name'    => $page['slug'],
            'post_content' => $page['content'],
            'post_status'  => 'publish',
            'post_type'    => 'page',
        ] );
        $results[] = "Seite '{$page['title']}' angelegt (ID: {$id})";
    }
}

// Startseite als Frontpage
$front = get_page_by_path( 'startseite' );
if ( $front ) {
    update_option( 'show_on_front', 'page' );
    update_option( 'page_on_front', $front->ID );
    $results[] = 'Frontpage gesetzt';
}

// Optionen importieren
foreach ( $payload['options'] as $key => $value ) {
    update_option( $key, $value );
}
$results[] = count( $payload['options'] ) . ' Optionen importiert';

// Permalinks
update_option( 'permalink_structure', '/%postname%/' );
flush_rewrite_rules();
$results[] = 'Permalinks gesetzt';

// Aufräumen
@unlink( __FILE__ );
$results[] = 'Setup-Script gelöscht';

header( 'Content-Type: text/plain; charset=utf-8' );
echo implode( "\n", $results ) . "\n";
PHPEOF

# Token einsetzen
sed -i '' "s/%%TOKEN%%/$SETUP_TOKEN/" "$TMP_DIR/srk-setup.php"

# ── 6. Hochladen und per POST ausführen ──
echo "→ Setup-Script hochladen und ausführen..."
$LFTP <<EOF
put "$TMP_DIR/srk-setup.php" -o "$FTP_WP_PATH/srk-setup.php"
quit
EOF

# Daten per POST senden — landen nur im RAM, nie auf der Festplatte
PAYLOAD=$(python3 -c "
import json
pages = json.load(open('$TMP_DIR/pages.json'))
options = json.load(open('$TMP_DIR/options.json'))
print(json.dumps({'pages': pages, 'options': options}))
")

RESULT=$(curl -sf -X POST \
  -H "Content-Type: application/json" \
  -H "X-Setup-Token: $SETUP_TOKEN" \
  -d "$PAYLOAD" \
  "$DOMAIN/srk-setup.php" 2>&1) || {
  echo "  FEHLER: Setup-Script konnte nicht ausgeführt werden."
  echo "  Prüfe ob WordPress unter $DOMAIN erreichbar ist."
  echo "  Lösche srk-setup.php manuell vom Server!"
  exit 1
}
echo "$RESULT" | sed 's/^/  /'

echo ""
echo "══════════════════════════════════════"
echo " Setup abgeschlossen!"
echo "══════════════════════════════════════"
echo ""
echo "Noch zu tun:"
echo "  1. SMTP konfigurieren (Admin > SRK SMTP Mailer)"
echo "  2. wp-config.php prüfen (Salts, Rechte 640)"
echo "  3. Wartungsmodus deaktivieren"
echo ""
