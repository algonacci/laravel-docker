#!/bin/bash

# Set your project name, PHP version, clone link, and domain
project_name="laravel-docker"
php_version="8.2"
clone_link="https://github.com/algonacci/laravel-docker.git" # Replace with your actual repository link
domain="laravel.braincore.id" # Replace with your actual domain or IP

sudo apt update -y
# Allow OpenSSH
echo "Configure Firewall (UFW)"

sudo ufw app list
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status

# Install Nginx
echo "Installing Nginx"
sudo apt update -y
sudo apt install nginx -y
sudo ufw app list
sudo ufw allow 'Nginx HTTP'
sudo ufw status

# Install MySQL
echo "Installing MySQL"
sudo apt install mysql-server -y

# Set your project name and MySQL credentials
mysql_user="$project_name"
mysql_password="secret"

# MySQL commands to create database, user, and grant privileges
sudo mysql <<MYSQL_SCRIPT
CREATE DATABASE $project_name;
CREATE USER '$mysql_user'@'%' IDENTIFIED WITH mysql_native_password BY '$mysql_password';
GRANT ALL ON $project_name.* TO '$mysql_user'@'%';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

echo "MySQL database, user, and privileges created successfully."

# adding PHP repository
echo "Installing PHP $php_version"

sudo apt install software-properties-common
sudo add-apt-repository ppa:ondrej/php
apt-get update -y

# Install PHP and required extensions
sudo apt install php$php_version-fpm php$php_version-mysql -y

# Install NVM and Node.js
echo "Installing NVM and Node.js"

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
command -v nvm
nvm install node

# Install Composer
echo "Installing Composer"

sudo apt install php$php_version-cli unzip -y
cd ~
curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
HASH=$(curl -sS https://composer.github.io/installer.sig)
echo $HASH
php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') == '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Install PHP and NPM dependencies
sudo apt install php$php_version php$php_version-cli php$php_version-common php$php_version-mbstring php$php_version-gd php$php_version-intl php$php_version-xml php$php_version-mysql php$php_version-zip php$php_version-xsl php$php_version-curl -y

# Clone the repository
echo "Cloning Repository"

git clone $clone_link $project_name

cd ~/$project_name

# Configure environment
cp .env.example .env
nano .env

# Install Laravel dependencies
composer install
php artisan key:generate
php artisan migrate --force

# Install NPM dependencies and build assets
npm install
npm run build

# Move project to web root
sudo mv ~/$project_name /var/www/$project_name

# Create symbolic link for storage
php artisan storage:link

# Set permissions
sudo chown -R $project_name:www-data /var/www/$project_name/storage
sudo chown -R $project_name:www-data /var/www/$project_name/bootstrap/cache
sudo chmod -R ugo+rwx /var/www/$project_name/storage
sudo chmod -R ugo+rwx /var/www/$project_name/public

# Set up Nginx configuration for Laravel
sudo tee /etc/nginx/sites-available/$project_name <<EOF
server {
    listen 80;
    server_name your_domain_or_ip;

    root /var/www/$project_name/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$php_version-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    error_log  /var/log/nginx/$project_name_error.log;
    access_log /var/log/nginx/$project_name_access.log;
}

EOF

# Create a symbolic link to enable the site
sudo ln -s /etc/nginx/sites-available/$project_name /etc/nginx/sites-enabled/

# Remove the default Nginx configuration
sudo unlink /etc/nginx/sites-enabled/default

# Test Nginx
sudo nginx -t

# Restart Nginx to apply changes
sudo systemctl restart nginx