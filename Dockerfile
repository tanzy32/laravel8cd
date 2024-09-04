# Use the official PHP image with FPM
FROM php:8.1-fpm

# Set working directory
WORKDIR /var/www/html

# Install system dependencies and PHP extensions
RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    zip \
    unzip \
    sudo \
    git \
    curl \
    xsltproc \
    procps \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo_mysql gd \
    && pecl install xdebug \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy existing application directory contents
COPY . /var/www/html

# Install PHP dependencies using Composer
RUN composer install --no-dev --optimize-autoloader

# Install Codeception
RUN composer require --dev codeception/codeception

# Configure Xdebug for code coverage
RUN mkdir -p /usr/local/etc/php/conf.d/ \
    && echo "zend_extension=xdebug.so" > /usr/local/etc/php/conf.d/20-xdebug.ini \
    && echo "xdebug.mode=coverage" >> /usr/local/etc/php/conf.d/20-xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/20-xdebug.ini

# Copy the XSL stylesheet for XML to HTML conversion
COPY phpunit-to-html.xsl /var/www/html/

# Generate application key
RUN php artisan key:generate --no-interaction

# Set permissions for Laravel
RUN chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html/storage \
    && chmod -R 755 /var/www/html/bootstrap/cache

# Ensure test directories exist
RUN mkdir -p /var/www/html/tests/Unit /var/www/html/reports/coverage

# Run PHPUnit and generate HTML code coverage report
RUN if [ -d "./tests/Unit" ]; then \
        vendor/bin/phpunit --coverage-html /var/www/html/reports/coverage; \
    else \
        echo "Skipping PHPUnit because test directory not found."; \
    fi

# Run Laravel tests and generate test report in JUnit XML format
RUN if [ -d "./tests" ]; then \
        php artisan test --log-junit /var/www/html/tests/report.xml; \
    else \
        echo "Skipping Laravel tests because test directory not found."; \
    fi

# Convert PHPUnit XML report
