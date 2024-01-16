FROM php:8.2-cli

COPY . /app
COPY .env.example /app/.env

RUN cat /app/.env

RUN docker-php-ext-install pdo pdo_mysql

RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    unzip \
    zip 

RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/bin --filename=composer

RUN cd /app && composer update
RUN cd /app && php artisan key:generate && php artisan migrate

WORKDIR /app

CMD php artisan serve --host=0.0.0.0 --port=8080

EXPOSE 8080