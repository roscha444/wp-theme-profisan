<?php
/**
 * Maintenance mode template for legal pages (Impressum, Datenschutz).
 * Shows minimal header/footer (same as maintenance.php) with the page content from the database.
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}
?>
<!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><?php echo esc_html( get_the_title() ); ?> — ProfiSan GmbH</title>
  <meta name="robots" content="noindex, nofollow">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Bitter:wght@400;500;600;700&family=Nunito+Sans:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <?php wp_enqueue_style( 'profisan-custom' ); wp_head(); ?>
</head>
<body>

  <header class="site-header" role="banner">
    <nav class="nav-container" aria-label="Hauptnavigation">
      <a href="/" class="logo-link" aria-label="ProfiSan GmbH Startseite">
        <img src="<?php echo esc_url( get_template_directory_uri() . '/assets/images/logo_profisan.png' ); ?>" alt="ProfiSan GmbH Logo" width="48" height="48">
      </a>
    </nav>
  </header>

  <main class="maintenance-legal-content">
    <div class="container" style="max-width: 800px; margin: 0 auto; padding: 160px 24px 80px;">
      <h1><?php echo esc_html( get_the_title() ); ?></h1>
      <?php
      // Output the page content from the database
      while ( have_posts() ) :
          the_post();
          the_content();
      endwhile;
      ?>
    </div>
  </main>

  <footer class="site-footer" role="contentinfo">
    <div class="footer-bottom">
      <span>&copy; <?php echo wp_date( 'Y' ); ?> ProfiSan GmbH. Alle Rechte vorbehalten.</span>
      <div class="footer-bottom-links">
        <a href="/impressum">Impressum</a>
        <a href="/datenschutz">Datenschutz</a>
        <span class="footer-bottom-separator">·</span>
        <a href="<?php echo esc_url( wp_login_url( home_url() ) ); ?>" class="maintenance-login-link">Kunden Login</a>
      </div>
    </div>
    <div class="footer-credit">
      <a href="https://srk-hosting.de" target="_blank" rel="noopener" class="footer-credit-link">Bereitgestellt von SRK Hosting</a>
    </div>
  </footer>

  <?php wp_footer(); ?>
</body>
</html>
