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

// ===== ProfiSan Kontaktformular (SRK Contact Forms Plugin) =====

function profisan_register_contact_form( $forms ) {
	$forms['profisan'] = array(
		'title'        => 'ProfiSan Kontaktformular',
		'recipient'    => 'info@profisan-gmbh.de',
		'subject'      => 'Kontaktanfrage über die Website',
		'fields'       => array(
			array(
				'name'        => 'name',
				'label'       => 'Name',
				'type'        => 'text',
				'required'    => true,
				'placeholder' => 'Ihr Name',
				'width'       => 'half',
			),
			array(
				'name'        => 'email',
				'label'       => 'E-Mail',
				'type'        => 'email',
				'required'    => true,
				'placeholder' => 'Ihre E-Mail-Adresse',
				'width'       => 'half',
			),
			array(
				'name'        => 'phone',
				'label'       => 'Telefon (optional)',
				'type'        => 'tel',
				'required'    => false,
				'placeholder' => 'Ihre Telefonnummer',
				'width'       => 'full',
			),
			array(
				'name'        => 'subject',
				'label'       => 'Betreff',
				'type'        => 'select',
				'required'    => true,
				'width'       => 'full',
				'options'     => array(
					''               => 'Bitte wählen...',
					'malerarbeiten'  => 'Maler- und Lackiererarbeiten',
					'wasserschaden'  => 'Brand- & Wasserschadensanierung',
					'schimmel'       => 'Schimmelsanierung',
					'altbau'         => 'Energetische Altbausanierung',
					'sonstiges'      => 'Sonstiges',
				),
			),
			array(
				'name'        => 'message',
				'label'       => 'Nachricht',
				'type'        => 'textarea',
				'required'    => true,
				'placeholder' => 'Beschreiben Sie kurz Ihr Anliegen...',
				'width'       => 'full',
			),
		),
		'privacy_page' => '/datenschutz/',
		'submit_label' => 'Nachricht senden',
		'success_msg'  => 'Vielen Dank für Ihre Anfrage! Wir melden uns in Kürze bei Ihnen.',
	);
	return $forms;
}
add_filter( 'srk_contact_forms', 'profisan_register_contact_form' );

// ===== Multi-Domain: .com als Demo, .de als primäre Domain =====

define( 'PROFISAN_PRIMARY_DOMAIN', 'www.profisan-gmbh.de' );
define( 'PROFISAN_DEMO_DOMAIN', 'www.profisan-gmbh.com' );

function profisan_is_demo_domain() {
	$host = isset( $_SERVER['HTTP_HOST'] ) ? strtolower( explode( ':', $_SERVER['HTTP_HOST'] )[0] ) : '';
	return in_array( $host, array( 'www.profisan-gmbh.com', 'profisan-gmbh.com' ), true );
}

// Demo-Domain: noindex + canonical auf .de
function profisan_demo_domain_head() {
	if ( ! profisan_is_demo_domain() ) {
		return;
	}
	echo '<meta name="robots" content="noindex, nofollow">' . "\n";

	$path = isset( $_SERVER['REQUEST_URI'] ) ? $_SERVER['REQUEST_URI'] : '/';
	$path = preg_replace( '#[\r\n\0]#', '', $path );
	$canonical = 'https://' . PROFISAN_PRIMARY_DOMAIN . $path;
	echo '<link rel="canonical" href="' . esc_url( $canonical ) . '">' . "\n";
}
add_action( 'wp_head', 'profisan_demo_domain_head', 1 );

// Demo-Domain: X-Robots-Tag Header als zusätzliche Absicherung
function profisan_demo_domain_headers() {
	if ( ! profisan_is_demo_domain() ) {
		return;
	}
	header( 'X-Robots-Tag: noindex, nofollow', true );
}
add_action( 'send_headers', 'profisan_demo_domain_headers' );

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
