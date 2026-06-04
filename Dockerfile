FROM php:5.6-apache

# Install MySQL extensions (mysql is deprecated in PHP 7.0+, but needed for PHP 5.6)
RUN docker-php-ext-install mysql mysqli

# Copy PHP configuration
COPY php.ini /usr/local/etc/php/php.ini

# Enable Apache mod_rewrite if needed
RUN a2enmod rewrite

# Set working directory
WORKDIR /var/www/html

# Expose port
EXPOSE 80

CMD ["apache2-foreground"]
