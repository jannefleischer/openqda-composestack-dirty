# syntax=docker/dockerfile:1.6

FROM php:8.2-cli AS base

ARG OPENQDA_GIT_URL
ARG OPENQDA_GIT_REF=main
ARG OPENQDA_APP_SUBDIR=web



# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    $PHPIZE_DEPS \
    pkgconf \
    libicu-dev \
    icu-devtools \
    libzip-dev \
    git unzip curl ca-certificates openssl \
    nodejs npm \
 && rm -rf /var/lib/apt/lists/*

# Wichtig: Multiarch pkg-config Pfad explizit setzen
ENV PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig

RUN docker-php-ext-configure intl \
 && docker-php-ext-install pdo_mysql zip intl

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /opt/openqda

# Clone (Build-time)
RUN test -n "${OPENQDA_GIT_URL}" || (echo "ERROR: OPENQDA_GIT_URL build-arg is required" && exit 1)
RUN git clone --depth 1 --branch "${OPENQDA_GIT_REF}" "${OPENQDA_GIT_URL}" /opt/openqda

# Laravel app lives in subdir (per doc: /web) :contentReference[oaicite:2]{index=2}
WORKDIR /opt/openqda/${OPENQDA_APP_SUBDIR}

# PHP deps
RUN composer install --no-interaction --prefer-dist --no-dev

# Frontend build (falls package.json existiert)
RUN if [ -f package.json ]; then \
      npm ci || npm install; \
      npm run build; \
    fi

# Runtime container
FROM php:8.2-cli

ARG OPENQDA_APP_SUBDIR=web

RUN apt-get update && apt-get install -y --no-install-recommends \
    libicu-dev libzip-dev libpng16-16 \
  && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install pdo_mysql zip intl

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# App rüberkopieren
WORKDIR /opt/openqda
COPY --from=base /opt/openqda /opt/openqda

# Entrypoint
COPY entrypoint.sh /opt/openqda/entrypoint.sh
RUN chmod +x /opt/openqda/entrypoint.sh

# Start script
COPY start.sh /opt/openqda/start.sh
RUN chmod +x /opt/openqda/start.sh

WORKDIR /opt/openqda/${OPENQDA_APP_SUBDIR}

EXPOSE 8000 8443
ENTRYPOINT ["/opt/openqda/entrypoint.sh"]
CMD ["/opt/openqda/start.sh"]