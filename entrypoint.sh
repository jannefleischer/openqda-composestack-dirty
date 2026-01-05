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

$set("APP_ENV", getenv("APP_ENV") ?: "local");
$set("APP_DEBUG", getenv("APP_DEBUG") ?: "true");
$set("APP_URL", getenv("APP_URL") ?: "http://localhost:8000");

$set("DB_CONNECTION", getenv("DB_CONNECTION") ?: "mysql");
$set("DB_HOST", getenv("DB_HOST") ?: "mysql");
$set("DB_PORT", getenv("DB_PORT") ?: "3306");
$set("DB_DATABASE", getenv("DB_DATABASE") ?: "openqda");
$set("DB_USERNAME", getenv("DB_USERNAME") ?: "sail");
$set("DB_PASSWORD", getenv("DB_PASSWORD") ?: "password");

$set("REDIS_HOST", getenv("REDIS_HOST") ?: "redis");
$set("REDIS_PORT", getenv("REDIS_PORT") ?: "6379");

$set("REVERB_SCHEME", getenv("REVERB_SCHEME") ?: "http");
$set("REVERB_SERVER_HOST", getenv("REVERB_SERVER_HOST") ?: "0.0.0.0");
$set("REVERB_SERVER_PORT", getenv("REVERB_SERVER_PORT") ?: "8080");

file_put_contents($path, $env);
'

# Key
php artisan key:generate --force >/dev/null || true

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

# Optional: script from your doc-based workflow :contentReference[oaicite:4]{index=4}
if [ "${RUN_DEBUG_SERVICES_SCRIPT:-false}" = "true" ] && [ -x "${APP_DIR}/start_debug_services.sh" ]; then
  "${APP_DIR}/start_debug_services.sh" || true
fi

exec "$@"
