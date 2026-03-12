<!DOCTYPE html>
<html <?php language_attributes(); ?>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>ProfiSan GmbH — Wartungsmodus</title>
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

  <section class="maintenance-page">
    <div class="maintenance-content">
      <div class="maintenance-icon">
        <svg width="64" height="64" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
          <path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/>
        </svg>
      </div>
      <h1>Wir arbeiten an unserer Webseite</h1>
      <p>Unsere Seite wird gerade überarbeitet und ist in Kürze wieder für Sie erreichbar.</p>
      <div class="maintenance-contact">
        <p>Sie erreichen uns weiterhin unter:</p>
        <div class="maintenance-contact-items">
          <a href="tel:0625182855211">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.127.96.361 1.903.7 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0 1 22 16.92z"/></svg>
            06251 - 82 855 211
          </a>
          <a href="mailto:info@profisan-gmbh.de">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>
            info@profisan-gmbh.de
          </a>
        </div>
      </div>
    </div>
  </section>

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
