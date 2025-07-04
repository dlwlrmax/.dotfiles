FROM php:8.3-fpm

# Install system dependencies
RUN apt-get update && apt-get install -y \
    libonig-dev \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libwebp-dev \
    libfreetype6-dev \
    libxml2-dev \
    libicu-dev \
    libsqlite3-dev \
    unzip \
    zip \
    curl \
    git \
    sqlite3 \
    g++ \
    npm \
    nodejs

RUN docker-php-ext-configure gd --with-jpeg --with-webp --with-freetype

# Install PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_sqlite \
    pdo_mysql \
    mbstring \
    zip \
    gd \
    bcmath \
    intl \
    xml

# 🧪 Install PCOV for code coverage
RUN pecl install pcov \
    && docker-php-ext-enable pcov

# Enable PCOV only for code coverage (not on by default)
RUN echo "pcov.enabled=1" > /usr/local/etc/php/conf.d/pcov.ini \
    && echo "pcov.directory=/var/www/html" >> /usr/local/etc/php/conf.d/pcov.ini


# Disable Xdebug if it sneaks in
RUN rm -f /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini || true

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy app files
COPY . .
COPY ./docker/php/php.ini /usr/local/etc/php/php.ini

# Install PHP dependencies
RUN composer install --no-interaction --prefer-dist --optimize-autoloader

# Set correct permissions
RUN chmod -R 775 storage/
RUN chown -R $USER:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 9000

CMD ["php-fpm"]