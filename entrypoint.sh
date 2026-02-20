#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${PWD}"

if [ ! -f "${APP_DIR}/.env" ]; then
  if [ -f "${APP_DIR}/.env.example" ]; then
    cp "${APP_DIR}/.env.example" "${APP_DIR}/.env"
  else
    touch "${APP_DIR}/.env"
  fi
fi

php -r '
$path = ".env";
$env = file_get_contents($path) ?: "";
$set = function($k,$v) use (&$env){
  $line = $k."=".$v;
  if (preg_match("/^".preg_quote($k,"/")."=.*/m",$env)) {
    $env = preg_replace("/^".preg_quote($k,"/")."=.*/m",$line,$env);
  } else {
    $env .= (strlen($env) ? "\n" : "").$line;
  }
};

$set("OPENQDA_GIT_URL", getenv("OPENQDA_GIT_URL") ?: "https://github.com/openqda/openqda.git");
$set("OPENQDA_GIT_REF", getenv("OPENQDA_GIT_REF") ?: "1.0.4");
$set("OPENQDA_APP_SUBDIR", getenv("OPENQDA_APP_SUBDIR") ?: "web");

$set("APP_ENV", getenv("APP_ENV") ?: "local");
$set("APP_KEY", getenv("APP_KEY") ?: "base64:b8t9cxd9X5Z496Kzn6P1GeweUMdO8wd94PuEZiXi4Wk=");
$set("APP_URL", getenv("APP_URL") ?: "https://openqda.example.local");
$set("ASSET_URL", getenv("ASSET_URL") ?: "https://openqda.example.local");
$set("APP_PORT", getenv("APP_PORT") ?: "8923");
$set("TRUSTED_PROXIES", getenv("TRUSTED_PROXIES") ?: "*");
$set("FORCE_HTTPS", getenv("FORCE_HTTPS") ?: "true");

$set("APP_DEBUG", getenv("APP_DEBUG") ?: getenv("DEBUG") ?: "true");
$set("LOG_LEVEL", getenv("LOG_LEVEL") ?: "debug");

// ALTCHA / CAPTCHA
$set("ALTCHA_EXPIRES", getenv("ALTCHA_EXPIRES") ?: "300");
$set("ALTCHA_ALGORITHM", getenv("ALTCHA_ALGORITHM") ?: "SHA-256");
$set("ALTCHA_ENABLE", getenv("ALTCHA_ENABLE") ?: "true");
$set("ALTCHA_HMAC_KEY", getenv("ALTCHA_HMAC_KEY") ?: "64b8e24c6fc4271c53fee28d370451728876a4466d0a515da6ca437ca35dfa06");

$set("MAIL_MAILER", getenv("MAIL_MAILER") ?: "smtp");
$set("MAIL_HOST", getenv("MAIL_HOST") ?: "mail.example.local");
$set("MAIL_PORT", getenv("MAIL_PORT") ?: "1025");
$set("MAIL_USERNAME", getenv("MAIL_USERNAME") ?: "openqda@example");
$set("MAIL_PASSWORD", getenv("MAIL_PASSWORD") ?: "securepw");
$set("MAIL_ENCRYPTION", getenv("MAIL_ENCRYPTION") ?: "");
$set("MAIL_FROM_ADDRESS", getenv("MAIL_FROM_ADDRESS") ?: "openqda@example.local");
$set("MAIL_FROM_NAME", getenv("MAIL_FROM_NAME") ?: "OpenQDA");

$set("REVERB_APP_KEY", getenv("REVERB_APP_KEY") ?: "local-key");
$set("VITE_REVERB_APP_KEY", getenv("VITE_REVERB_APP_KEY") ?: "local-key");
$set("REVERB_APP_ID", getenv("REVERB_APP_ID") ?: "local");
$set("REVERB_APP_SECRET", getenv("REVERB_APP_SECRET") ?: "local-secret");
$set("REVERB_SCHEME", getenv("REVERB_SCHEME") ?: "http");
$set("REVERB_SERVER_HOST", getenv("REVERB_SERVER_HOST") ?: "0.0.0.0");
$set("REVERB_SERVER_PORT", getenv("REVERB_SERVER_PORT") ?: "8443");
$set("REVERB_PORT", getenv("REVERB_PORT") ?: "8443");
$set("VITE_REVERB_HOST", getenv("VITE_REVERB_HOST") ?: "localhost");
$set("VITE_REVERB_PORT", getenv("VITE_REVERB_PORT") ?: "8443");
$set("VITE_REVERB_SCHEME", getenv("VITE_REVERB_SCHEME") ?: "http");

$set("DB_CONNECTION", getenv("DB_CONNECTION") ?: "mysql");
$set("DB_HOST", getenv("DB_HOST") ?: "mysql");
$set("DB_PORT", getenv("DB_PORT") ?: "3306");
$set("DB_DATABASE", getenv("DB_DATABASE") ?: "openqda");
$set("DB_USERNAME", getenv("DB_USERNAME") ?: "sail");
$set("DB_PASSWORD", getenv("DB_PASSWORD") ?: "password");

$set("REDIS_HOST", getenv("REDIS_HOST") ?: "redis");
$set("REDIS_PORT", getenv("REDIS_PORT") ?: "6379");

// Clear LARAVEL_WEBSOCKETS_SSL variables (not needed for Reverb without SSL)
$env = preg_replace("/^LARAVEL_WEBSOCKETS_SSL_.*=.*$/m", "", $env);
$env = preg_replace("/\n\n+/", "\n", $env);

file_put_contents($path, $env);
'

# Debug output: Show ALTCHA configuration
if [ "${APP_DEBUG:-false}" = "true" ]; then
  echo "=== ALTCHA Configuration ==="
  grep "^ALTCHA" "${APP_DIR}/.env" || echo "No ALTCHA settings found"
  echo "============================"
fi

# Generate self-signed certificates if not provided
CERT_DIR=/opt/certs
REQUESTED_CERT=${REVERB_SSL_CERT:-/opt/certs/cert.pem}

mkdir -p "$CERT_DIR"

if [ -e "$REQUESTED_CERT" ]; then
  REAL=$(readlink -f "$REQUESTED_CERT" 2>/dev/null || true)
  if [ -n "$REAL" ] && [ -f "$REAL" ]; then
    echo "Using cert target $REAL"
    cp "$REAL" "$CERT_DIR/cert.pem" || true
    DIR=$(dirname "$REAL")
    [ -f "$DIR/privkey.pem" ] && cp "$DIR/privkey.pem" "$CERT_DIR/privkey.pem" || true
    [ -f "$DIR/fullchain.pem" ] && cp "$DIR/fullchain.pem" "$CERT_DIR/fullchain.pem" || true
  else
    echo "Certificate path exists but target not found: $REQUESTED_CERT" >&2
  fi
else
  echo "No cert found at $REQUESTED_CERT — generating self-signed cert"
  openssl req -x509 -newkey rsa:4096 -keyout "$CERT_DIR/privkey.pem" -out "$CERT_DIR/cert.pem" -days 365 -nodes -subj "/C=DE/ST=State/L=City/O=Organization/CN=localhost"
  cp "$CERT_DIR/cert.pem" "$CERT_DIR/fullchain.pem" || true
fi

# APP_KEY: Only generate if not provided via environment variable
if [ -z "${APP_KEY:-}" ]; then
  echo "No APP_KEY provided, generating new one..."
  php artisan key:generate --force >/dev/null || true
else
  echo "Using provided APP_KEY from environment"
fi

# Optional init steps
if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  php artisan migrate --force || true
fi

if [ "${RUN_SEED:-true}" = "true" ]; then
  php artisan db:seed --force || true
fi

if [ "${RUN_STORAGE_LINK:-true}" = "true" ]; then
  php artisan storage:link || true
fi

# Handle TRUSTED_PROXIES: monkeypatch $proxies in TrustProxies middleware
if [ -n "${TRUSTED_PROXIES:-}" ]; then
  TARGET="${APP_DIR}/app/Http/Middleware/TrustProxies.php"
  if [ -f "$TARGET" ]; then
    if [ "${TRUSTED_PROXIES}" = "*" ]; then
      replacement="protected \$proxies = '*';"
    else
      list=$(printf "%s" "$TRUSTED_PROXIES" | sed -E "s/[[:space:]]*,[[:space:]]*/','/g; s/^[[:space:]]+|[[:space:]]+\$//g")
      replacement="protected \$proxies = ['$list'];"
    fi
    # Match both with and without assignment (= ...; or just ;)
    sed -i -E "s|^([[:space:]]*)protected[[:space:]]+\\\$proxies[[:space:]]*(=.*)?;|\1$replacement|" "$TARGET" || true
    echo "Patched TrustProxies with: $replacement"
  else
    echo "TrustProxies middleware not found at $TARGET" >&2
  fi
fi

# Force HTTPS in Laravel
if [ "${FORCE_HTTPS:-false}" = "true" ]; then
    TARGET="${APP_DIR}/app/Providers/AppServiceProvider.php"
    if [ -f "$TARGET" ]; then
        # Check if URL::forceScheme is already present
        if ! grep -q "URL::forceScheme" "$TARGET"; then
            echo "Patching AppServiceProvider to force HTTPS..."
            
            # Backup original
            cp "$TARGET" "${TARGET}.bak"
            
            # Use awk for more reliable patching
            awk '
            /^namespace/ {
                print
                if (!use_added) {
                    print "use Illuminate\\Support\\Facades\\URL;"
                    use_added = 1
                }
                next
            }
            /public function boot\(\)/ {
                print
                getline
                print
                if (!scheme_added) {
                    print "        URL::forceScheme(\"https\");"
                    scheme_added = 1
                }
                next
            }
            { print }
            ' "$TARGET" > "${TARGET}.tmp" && mv "${TARGET}.tmp" "$TARGET"
            
            echo "AppServiceProvider patched successfully"
        else
            echo "AppServiceProvider already contains URL::forceScheme"
        fi
    else
        echo "AppServiceProvider not found at $TARGET" >&2
    fi
    
fi

php artisan config:clear
php artisan route:clear
php artisan view:clear

exec "$@"
