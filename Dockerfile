ARG ALPINE="alpine:3.23"
ARG YTDLP="2026.08.19"
ARG ALLTUBE="3.2.0-alpha"

# --------------------------------------------------
# Composer
# --------------------------------------------------
FROM ${ALPINE} AS composer

RUN apk add --no-cache \
    php84 \
    php84-phar \
    php84-mbstring \
    php84-openssl \
    php84-json \
    wget

RUN wget https://install.phpcomposer.com/installer -O - | php

# --------------------------------------------------
# AllTube
# --------------------------------------------------
FROM ${ALPINE} AS alltube

ARG ALLTUBE

RUN apk add --no-cache \
    php84 \
    php84-phar \
    php84-session \
    php84-curl \
    php84-dom \
    php84-gmp \
    php84-gettext \
    php84-intl \
    php84-json \
    php84-mbstring \
    php84-openssl \
    php84-simplexml \
    php84-tokenizer \
    php84-xml \
    php84-xmlwriter \
    php84-zip \
    wget

RUN ln -sf /usr/bin/php84 /usr/bin/php

WORKDIR /tmp

RUN wget \
    "https://github.com/Rudloff/alltube/archive/${ALLTUBE}.tar.gz" \
    -O alltube.tar.gz \
    && tar xzf alltube.tar.gz \
    && mv "alltube-${ALLTUBE}" /alltube

COPY --from=composer /composer.phar /usr/bin/composer

WORKDIR /alltube

RUN composer install \
    --no-interaction \
    --optimize-autoloader \
    --no-dev

# --------------------------------------------------
# AllTube configuration
# --------------------------------------------------
RUN mv config/config.example.yml config/config.yml

RUN sed -i \
    's/^remux: false/remux: true/' \
    config/config.yml

RUN sed -i \
    's/^convert: false/convert: true/' \
    config/config.yml

# Keep normal video downloads as the default
RUN sed -i \
    's/^defaultAudio: false/defaultAudio: false/' \
    config/config.yml

COPY attach.css /tmp/attach.css

RUN cat /tmp/attach.css >> css/style.css

# AllTube template cache must be writable
RUN chmod 777 templates_c

# --------------------------------------------------
# Final image
# --------------------------------------------------
FROM ${ALPINE}

ARG YTDLP

RUN apk add --no-cache \
    nginx \
    ffmpeg \
    python3 \
    py3-pip \
    deno \
    ca-certificates \
    php84 \
    php84-fpm \
    php84-session \
    php84-curl \
    php84-dom \
    php84-gmp \
    php84-gettext \
    php84-intl \
    php84-json \
    php84-mbstring \
    php84-openssl \
    php84-phar \
    php84-simplexml \
    php84-tokenizer \
    php84-xml \
    php84-xmlwriter \
    php84-zip

RUN ln -sf /usr/bin/php84 /usr/bin/php

# --------------------------------------------------
# Verify PHP session extension
# --------------------------------------------------
RUN php -m | grep -i session

# --------------------------------------------------
# Install modern yt-dlp
# --------------------------------------------------
RUN python3 -m pip install \
    --break-system-packages \
    --no-cache-dir \
    "yt-dlp[default]==${YTDLP}"

# Verify yt-dlp + Python + Deno
RUN python3 --version \
    && yt-dlp --version \
    && deno --version

# --------------------------------------------------
# AllTube files
# --------------------------------------------------
COPY --from=alltube /alltube /var/www/alltube

# PHP-FPM runs as nobody
RUN chown -R nobody:nobody /var/www/alltube

COPY nginx/ /etc/nginx/

COPY init.sh /usr/bin/alltube

# AllTube's original script uses php-fpm7.
# Modern Alpine uses php-fpm84.
RUN sed -i \
    's#/usr/sbin/php-fpm7#/usr/sbin/php-fpm84#g' \
    /usr/bin/alltube

RUN chmod +x /usr/bin/alltube

# --------------------------------------------------
# PHP-FPM socket
# --------------------------------------------------
RUN sed -i \
    's#^listen = .*#listen = /run/php-fpm.sock#' \
    /etc/php84/php-fpm.d/www.conf

# --------------------------------------------------
# Writable download directory
# --------------------------------------------------
RUN mkdir -p /tmp/alltube-downloads \
    && chown nobody:nobody /tmp/alltube-downloads \
    && chmod 700 /tmp/alltube-downloads

WORKDIR /tmp/alltube-downloads

EXPOSE 80

ENTRYPOINT ["alltube"]
