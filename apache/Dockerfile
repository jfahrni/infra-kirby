FROM php:8.3-apache

# PHP-Extensions für Kirby CMS
RUN apt-get update && apt-get install -y \
        libgd-dev \
        libzip-dev \
        libpng-dev \
        libjpeg-dev \
        libwebp-dev \
        libavif-dev \
        libfreetype6-dev \
    && docker-php-ext-configure gd --with-jpeg --with-webp --with-avif --with-freetype \
    && docker-php-ext-install -j$(nproc) gd zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Apache-Module aktivieren
RUN a2enmod rewrite deflate expires headers

# PHP OPcache aktivieren
RUN docker-php-ext-install opcache
RUN echo "opcache.enable=1\nopcache.memory_consumption=128\nopcache.max_accelerated_files=4000\nopcache.revalidate_freq=60" \
    > /usr/local/etc/php/conf.d/opcache.ini

# Upload-Limits
RUN echo "upload_max_filesize=32M" > /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size=32M" >> /usr/local/etc/php/conf.d/uploads.ini

# Apache VirtualHost-Konfiguration
COPY apache.conf /etc/apache2/sites-available/000-default.conf

# www-data auf Host-UID anpassen (Bind Mount Kompatibilität)
ARG HOST_UID=1000
RUN usermod -u ${HOST_UID} www-data && groupmod -g ${HOST_UID} www-data

EXPOSE 80
