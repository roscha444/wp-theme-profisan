<?php
/**
 * ProfiSan GmbH Theme Functions
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

function profisan_enqueue_assets() {
	// Custom CSS (includes local @font-face declarations)
	wp_enqueue_style(
		'profisan-custom',
		get_template_directory_uri() . '/assets/css/custom.css',
		array(),
		wp_get_theme()->get( 'Version' )
	);

	// Fade-in script
	wp_enqueue_script(
		'profisan-fade-in',
		get_template_directory_uri() . '/assets/js/fade-in.js',
		array(),
		wp_get_theme()->get( 'Version' ),
		true
	);
}
add_action( 'wp_enqueue_scripts', 'profisan_enqueue_assets' );

function profisan_setup() {
	add_theme_support( 'wp-block-styles' );
	add_theme_support( 'editor-styles' );
	add_editor_style( 'assets/css/custom.css' );
}
add_action( 'after_setup_theme', 'profisan_setup' );

// Favicon
function profisan_favicon() {
	$dir = get_template_directory_uri() . '/assets/images';
	echo '<link rel="icon" type="image/png" sizes="32x32" href="' . esc_url( $dir . '/favicon-32.png' ) . '">' . "\n";
	echo '<link rel="apple-touch-icon" sizes="180x180" href="' . esc_url( $dir . '/apple-touch-icon.png' ) . '">' . "\n";
	echo '<link rel="icon" type="image/png" sizes="512x512" href="' . esc_url( $dir . '/favicon-512.png' ) . '">' . "\n";
}
add_action( 'wp_head', 'profisan_favicon' );

// ===== Wartungsmodus =====

// ===== Wartungsmodus – Einstellungsseite =====

function profisan_settings_menu() {
	add_theme_page(
		'ProfiSan Einstellungen',
		'ProfiSan Einstellungen',
		'manage_options',
		'profisan-settings',
		'profisan_settings_page'
	);
}
add_action( 'admin_menu', 'profisan_settings_menu' );

function profisan_settings_init() {
	register_setting( 'profisan_settings', 'profisan_maintenance_mode', array(
		'type'              => 'boolean',
		'default'           => false,
		'sanitize_callback' => 'rest_sanitize_boolean',
	) );
}
add_action( 'admin_init', 'profisan_settings_init' );

function profisan_settings_page() {
	$maintenance = get_option( 'profisan_maintenance_mode', false );
	?>
	<div class="wrap">
		<h1>ProfiSan Einstellungen</h1>
		<form method="post" action="options.php">
			<?php settings_fields( 'profisan_settings' ); ?>
			<table class="form-table">
				<tr>
					<th scope="row">Wartungsmodus</th>
					<td>
						<label>
							<input type="checkbox" name="profisan_maintenance_mode" value="1" <?php checked( $maintenance ); ?>>
							Wartungsmodus aktivieren
						</label>
						<p class="description">Wenn aktiv, sehen Besucher nur eine Wartungsseite mit Kontaktdaten. Admins sehen die Seite normal.</p>
					</td>
				</tr>
			</table>
			<?php submit_button( 'Speichern' ); ?>
		</form>
	</div>
	<?php
}

function profisan_maintenance_redirect() {
	if ( ! get_option( 'profisan_maintenance_mode', false ) ) {
		return;
	}

	if ( current_user_can( 'manage_options' ) ) {
		return;
	}

	// Impressum und Datenschutz: eigenes Wartungs-Layout mit Inhalt
	if ( is_page( array( 'impressum', 'datenschutz' ) ) ) {
		status_header( 503 );
		header( 'Retry-After: 3600' );
		nocache_headers();
		include get_template_directory() . '/templates/maintenance-legal.php';
		exit;
	}

	status_header( 503 );
	header( 'Retry-After: 3600' );
	nocache_headers();
	include get_template_directory() . '/templates/maintenance.php';
	exit;
}
add_action( 'template_redirect', 'profisan_maintenance_redirect' );

// REST API im Wartungsmodus blockieren (außer für Admins)
function profisan_maintenance_rest_block( $result ) {
	if ( ! get_option( 'profisan_maintenance_mode', false ) ) {
		return $result;
	}
	if ( is_user_logged_in() && current_user_can( 'manage_options' ) ) {
		return $result;
	}
	return new WP_Error(
		'maintenance_mode',
		'Die Webseite wird gerade überarbeitet.',
		array( 'status' => 503 )
	);
}
add_filter( 'rest_authentication_errors', 'profisan_maintenance_rest_block' );

// Feeds im Wartungsmodus blockieren
function profisan_maintenance_feed_block() {
	if ( ! get_option( 'profisan_maintenance_mode', false ) ) {
		return;
	}
	if ( current_user_can( 'manage_options' ) ) {
		return;
	}
	status_header( 503 );
	header( 'Retry-After: 3600' );
	wp_die( 'Die Webseite wird gerade überarbeitet.', 'Wartungsmodus', array( 'response' => 503 ) );
}
add_action( 'do_feed', 'profisan_maintenance_feed_block', 1 );
add_action( 'do_feed_rdf', 'profisan_maintenance_feed_block', 1 );
add_action( 'do_feed_rss', 'profisan_maintenance_feed_block', 1 );
add_action( 'do_feed_rss2', 'profisan_maintenance_feed_block', 1 );
add_action( 'do_feed_atom', 'profisan_maintenance_feed_block', 1 );

// Theme-Bilder im Wartungsmodus schützen
function profisan_maintenance_block_images() {
	if ( ! get_option( 'profisan_maintenance_mode', false ) ) {
		return;
	}
	if ( current_user_can( 'manage_options' ) ) {
		return;
	}
	$request_uri = isset( $_SERVER['REQUEST_URI'] ) ? $_SERVER['REQUEST_URI'] : '';
	$request_uri = preg_replace( '#[\r\n\0]#', '', rawurldecode( $request_uri ) );
	if ( strpos( $request_uri, '/wp-content/themes/profisan-theme/assets/images/' ) !== false ) {
		status_header( 403 );
		exit;
	}
}
add_action( 'init', 'profisan_maintenance_block_images' );
