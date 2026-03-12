#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════
# ProfiSan — Einmal-Migration auf den Server
# ═══════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.sh"

SSH="ssh -p $SSH_PORT $SSH_HOST"
REMOTE_THEME="$WP_PATH/wp-content/themes/profisan-theme"
REMOTE_PLUGINS="$WP_PATH/wp-content/plugins"

echo "══════════════════════════════════════"
echo " ProfiSan — Server-Setup"
echo "══════════════════════════════════════"
echo ""
echo "Server:  $SSH_HOST"
echo "WP-Path: $WP_PATH"
echo "Domain:  $DOMAIN"
echo ""
read -p "Fortfahren? (j/n) " -n 1 -r
echo
[[ $REPLY =~ ^[Jj]$ ]] || exit 1

# ── 1. Theme installieren ──
echo ""
echo "→ Theme installieren..."
$SSH "
  if [ -d '$REMOTE_THEME/.git' ]; then
    echo '  Theme-Repo existiert, pull...'
    cd '$REMOTE_THEME' && git pull
  else
    echo '  Theme clonen...'
    git clone '$THEME_REPO' '$REMOTE_THEME'
  fi
"

# ── 2. Plugins installieren ──
echo "→ Plugins installieren..."
$SSH "
  TMP_DIR=\$(mktemp -d)
  git clone '$PLUGINS_REPO' \"\$TMP_DIR\"

  for PLUGIN in srk-security srk-contact-forms srk-smtp-mailer; do
    TARGET='$REMOTE_PLUGINS/'\$PLUGIN
    if [ -d \"\$TARGET\" ]; then
      echo \"  \$PLUGIN: update...\"
      rm -rf \"\$TARGET\"
    else
      echo \"  \$PLUGIN: install...\"
    fi
    cp -R \"\$TMP_DIR/\$PLUGIN\" \"\$TARGET\"
  done

  rm -rf \"\$TMP_DIR\"
"

# ── 3. Theme + Plugins aktivieren ──
echo "→ Theme und Plugins aktivieren..."
$SSH "
  cd '$WP_PATH'
  $WP_CLI theme activate profisan-theme
  $WP_CLI plugin activate srk-security srk-contact-forms srk-smtp-mailer
"

# ── 4. Seiten anlegen ──
echo "→ Seiten anlegen..."
$SSH "
  cd '$WP_PATH'

  # Startseite
  if ! $WP_CLI post list --post_type=page --name=startseite --field=ID 2>/dev/null | grep -q .; then
    $WP_CLI post create --post_type=page --post_title='Startseite' --post_status=publish --post_name=startseite
    echo '  Startseite angelegt'
  else
    echo '  Startseite existiert'
  fi

  # Impressum
  if ! $WP_CLI post list --post_type=page --name=impressum --field=ID 2>/dev/null | grep -q .; then
    $WP_CLI post create --post_type=page --post_title='Impressum' --post_status=publish --post_name=impressum
    echo '  Impressum angelegt'
  else
    echo '  Impressum existiert'
  fi

  # Datenschutz
  if ! $WP_CLI post list --post_type=page --name=datenschutz --field=ID 2>/dev/null | grep -q .; then
    $WP_CLI post create --post_type=page --post_title='Datenschutzerklärung' --post_status=publish --post_name=datenschutz
    echo '  Datenschutz angelegt'
  else
    echo '  Datenschutz existiert'
  fi

  # Startseite als Frontpage
  FRONT_ID=\$($WP_CLI post list --post_type=page --name=startseite --field=ID)
  $WP_CLI option update show_on_front page
  $WP_CLI option update page_on_front \"\$FRONT_ID\"
  echo '  Frontpage gesetzt'
"

# ── 5. Kontaktformular in DB anlegen ──
echo "→ Kontaktformular konfigurieren..."
$SSH "
  cd '$WP_PATH'
  $WP_CLI eval '
    \$forms = [
      \"profisan\" => [
        \"title\"        => \"ProfiSan Kontaktformular\",
        \"recipient\"    => \"info@profisan-gmbh.de\",
        \"subject\"      => \"Kontaktanfrage über die Website\",
        \"fields\"       => [
          [\"name\" => \"name\", \"label\" => \"Name\", \"type\" => \"text\", \"required\" => true, \"placeholder\" => \"Ihr Name\", \"width\" => \"half\"],
          [\"name\" => \"email\", \"label\" => \"E-Mail\", \"type\" => \"email\", \"required\" => true, \"placeholder\" => \"Ihre E-Mail-Adresse\", \"width\" => \"half\"],
          [\"name\" => \"phone\", \"label\" => \"Telefon (optional)\", \"type\" => \"tel\", \"required\" => false, \"placeholder\" => \"Ihre Telefonnummer\", \"width\" => \"full\"],
          [\"name\" => \"subject\", \"label\" => \"Betreff\", \"type\" => \"select\", \"required\" => true, \"width\" => \"full\", \"options\" => [\"\" => \"Bitte wählen...\", \"malerarbeiten\" => \"Maler- und Lackiererarbeiten\", \"wasserschaden\" => \"Brand- & Wasserschadensanierung\", \"schimmel\" => \"Schimmelsanierung\", \"altbau\" => \"Energetische Altbausanierung\", \"sonstiges\" => \"Sonstiges\"]],
          [\"name\" => \"message\", \"label\" => \"Nachricht\", \"type\" => \"textarea\", \"required\" => true, \"placeholder\" => \"Beschreiben Sie kurz Ihr Anliegen...\", \"width\" => \"full\"],
        ],
        \"privacy_page\" => \"/datenschutz/\",
        \"submit_label\" => \"Nachricht senden\",
        \"success_msg\"  => \"Vielen Dank für Ihre Anfrage! Wir melden uns in Kürze bei Ihnen.\",
      ],
    ];
    update_option(\"srk_cf_forms\", \$forms);
    echo \"Formular gespeichert\";
  '
"

# ── 6. Wartungsmodus + Grundeinstellungen ──
echo "→ Einstellungen setzen..."
$SSH "
  cd '$WP_PATH'
  $WP_CLI option update profisan_maintenance_mode 1
  $WP_CLI option update srk_sec_csp_enabled 1
  $WP_CLI option update srk_sec_upgrade_insecure 1
  $WP_CLI option update blogname 'ProfiSan GmbH'
  $WP_CLI option update blogdescription 'Maler- und Lackierbetrieb'
  $WP_CLI rewrite structure '/%postname%/'
  $WP_CLI rewrite flush
  echo '  Wartungsmodus: AN'
  echo '  CSP: AN'
  echo '  HTTPS: AN'
"

# ── 7. Sicherheits-Cleanup ──
echo "→ Sicherheits-Cleanup..."
$SSH "
  cd '$WP_PATH'
  rm -f readme.html license.txt wp-config-sample.php
  echo '  Standarddateien entfernt'

  # Default-Themes entfernen
  for THEME in twentytwentythree twentytwentyfour twentytwentyfive; do
    if [ -d 'wp-content/themes/'\$THEME ]; then
      rm -rf 'wp-content/themes/'\$THEME
      echo \"  \$THEME entfernt\"
    fi
  done
"

echo ""
echo "══════════════════════════════════════"
echo " Setup abgeschlossen!"
echo "══════════════════════════════════════"
echo ""
echo "Noch zu tun:"
echo "  1. Seiteninhalte im Block-Editor einfügen"
echo "  2. SMTP konfigurieren (Admin > SRK SMTP Mailer)"
echo "  3. wp-config.php prüfen (Salts, Rechte 640)"
echo "  4. Wartungsmodus deaktivieren"
echo ""
