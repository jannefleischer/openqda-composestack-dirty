#!/usr/bin/env bash
set -euo pipefail

# Start queue worker in background
php artisan queue:work --queue=conversion,default &

# Start Reverb in background
php artisan reverb:start &

# Start the web server
exec php artisan serve --host=0.0.0.0 --port=8000