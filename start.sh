#!/usr/bin/env bash
set -euo pipefail

# Function to read a value from the .env file
function get_env_value() {
    grep "^${1}=" .env 2>/dev/null | cut -d '=' -f2- | tr -d '"' || echo ""
}

# Check if debug mode is enabled via APP_DEBUG
if [ "${APP_DEBUG:-false}" = "true" ]; then
    echo "=== OpenQDA Debug Mode ==="
    
    # Get configuration from .env
    REVERB_HOST=$(get_env_value "REVERB_SERVER_HOST")
    REVERB_PORT=$(get_env_value "REVERB_SERVER_PORT")
    APP_URL=$(get_env_value "APP_URL")
    VITE_REVERB_HOST=$(get_env_value "VITE_REVERB_HOST")
    VITE_REVERB_PORT=$(get_env_value "VITE_REVERB_PORT")
    VITE_REVERB_SCHEME=$(get_env_value "VITE_REVERB_SCHEME")
    
    echo "APP_URL: ${APP_URL:-not set}"
    echo "Reverb Server: ${REVERB_HOST:-0.0.0.0}:${REVERB_PORT:-8443}"
    echo "Vite Reverb: ${VITE_REVERB_SCHEME:-https}://${VITE_REVERB_HOST:-localhost}:${VITE_REVERB_PORT:-8443}"
    echo "============================="
    
    # Cleanup function
    cleanup() {
        echo "Stopping services..."
        [ -n "${WEBSOCKET_PID:-}" ] && kill $WEBSOCKET_PID 2>/dev/null || true
        [ -n "${QUEUE_WORKER_PID:-}" ] && kill $QUEUE_WORKER_PID 2>/dev/null || true
        [ -n "${SERVER_PID:-}" ] && kill $SERVER_PID 2>/dev/null || true
        exit 0
    }
    trap cleanup SIGTERM SIGINT EXIT
    
    # Start WebSocket server with debug output
    echo "Starting Reverb WebSocket server..."
    php artisan reverb:start --debug --host="${REVERB_HOST:-0.0.0.0}" --port="${REVERB_PORT:-8443}" &
    WEBSOCKET_PID=$!
    echo "Reverb PID: $WEBSOCKET_PID"
    
    # Start Queue worker with verbose output
    echo "Starting Queue worker..."
    php artisan queue:work --queue=conversion,default --verbose &
    QUEUE_WORKER_PID=$!
    echo "Queue Worker PID: $QUEUE_WORKER_PID"
    
    # Start web server
    echo "Starting web server..."
    php artisan serve --host=0.0.0.0 --port=8000 &
    SERVER_PID=$!
    echo "Web Server PID: $SERVER_PID"
    
    echo "============================="
    echo "Services started. Press Ctrl+C to stop."
    echo "Web: http://0.0.0.0:8000"
    echo "WebSocket: ${VITE_REVERB_SCHEME:-https}://${REVERB_HOST:-0.0.0.0}:${REVERB_PORT:-8443}"
    echo "============================="
    
    # Wait for any process to exit
    wait -n $WEBSOCKET_PID $QUEUE_WORKER_PID $SERVER_PID
    
    # If we reach here, one process died
    cleanup
else
    # Normal mode: Start services in background
    
    # Start queue worker in background
    php artisan queue:work --queue=conversion,default &
    
    # Start Reverb in background
    php artisan reverb:start &
    
    # Start the web server in foreground
    exec php artisan serve --host=0.0.0.0 --port=8000
fi