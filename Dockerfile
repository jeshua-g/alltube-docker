ARG ALPINE="alpine:3.23"
ARG YTDLP="2026.08.19"
ARG ALLTUBE="3.2.0-alpha"

# ---------------------------------------------------------
# Build AllTube + install yt-dlp
# ---------------------------------------------------------
FROM ${ALPINE} AS build

ARG YTDLP
ARG ALLTUBE

RUN apk add --no-cache \
    php84 \
    php84-phar \
    php84-curl \
    php84-dom \
    php84-gmp \
    php84-gettext \
    php84-intl \
    php84-mbstring \
    php84-openssl \
    php84-simplexml \
    php84-tokenizer \
    php84-xml \
    php84-xmlwriter \
    php84-zip \
    composer \
    python3 \
    py3-pip \
    deno \
    wget \
    ca-certificates

# Alpine's PHP binary is named php84
RUN ln -sf /usr/bin/php84 /usr/local/bin/php

# ---------------------------------------------------------
# Install AllTube
# ---------------------------------------------------------
WORKDIR /tmp

RUN wget \
    "https://github.com/Rudloff/alltube/archive/${ALLTUBE}.tar.gz" \
    -O alltube.tar.gz \
    && tar xzf alltube.tar.gz \
    && mv "alltube-${ALLTUBE}" /alltube

WORKDIR /alltube

RUN cp config/config.example.yml config/config.yml

# Add the custom CSS from the original Docker project
COPY attach.css /tmp/attach.css

RUN cat /tmp/attach.css >> css/style.css

# Install PHP dependencies
RUN composer install \
    --no-interaction \
    --optimize-autoloader \
    --no-dev

RUN chmod 777 templates_c/

# ---------------------------------------------------------
# Install modern yt-dlp
# ---------------------------------------------------------
RUN python3 -m pip install \
    --break-system-packages \
    --no-cache-dir \
    "yt-dlp[default]==${YTDLP}"

# Verify versions during Docker build
RUN python3 --version \
    && yt-dlp --version \
    && deno --version

# ---------------------------------------------------------
# Final image
# ---------------------------------------------------------
FROM ${ALPINE}

RUN apk add --no-cache \
    nginx \
    ffmpeg \
    python3 \
    deno \
    php84 \
    php84-fpm \
    php84-curl \
    php84-dom \
    php84-gmp \
    php84-gettext \
    php84-intl \
    php84-mbstring \
    php84-openssl \
    php84-phar \
    php84-simplexml \
    php84-tokenizer \
    php84-xml \
    php84-xmlwriter \
    php84-zip \
    ca-certificates

# AllTube's init script expects the generic PHP command
RUN ln -sf /usr/bin/php84 /usr/local/bin/php

# Copy AllTube application
COPY --from=build /alltube /var/www/alltube

# Copy yt-dlp and its Python environment
COPY --from=build /usr/bin/yt-dlp /usr/bin/yt-dlp
COPY --from=build /usr/lib/python3.12 /usr/lib/python3.12

# Copy nginx configuration
COPY nginx/ /etc/nginx/

# Copy startup script
COPY init.sh /usr/bin/alltube

# The original init.sh expects php-fpm7.
# Modern Alpine uses php-fpm84.
RUN sed -i \
    's#/usr/sbin/php-fpm7#/usr/sbin/php-fpm84#g' \
    /usr/bin/alltube

# Configure PHP-FPM to use the socket expected by nginx
RUN sed -i \
    's#^listen = .*#listen = /run/php-fpm.sock#' \
    /etc/php84/php-fpm.d/www.conf

# Ensure startup script is executable
RUN chmod +x /usr/bin/alltube

EXPOSE 80

ENTRYPOINT ["alltube"]
