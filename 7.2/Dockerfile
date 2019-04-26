FROM php:7.2-fpm-stretch

# Container containing php-fpm and php-cli to run and interact with eZ Platform and other Symfony projects
#
# It has two modes of operation:
# - (run.sh cmd) [default] Reconfigure eZ Platform/Publish based on provided env variables and start php-fpm
# - (bash|php|composer) Allows to execute composer, php or bash against the image

# Set defaults for variables used by run.sh
ENV COMPOSER_HOME=/root/.composer

# Get packages that we need in container
RUN apt-get update -q -y \
    && apt-get install -q -y --no-install-recommends \
        ca-certificates \
	    bash \
	    procps \
        curl \
        acl \
        sudo \
	    mysql-client \
        openssh-client \
# Needed for the php extensions we enable below
        libxml2 \
        libfreetype6 \
        libjpeg62-turbo \
        libxpm4 \
        libpng16-16 \
        libicu57 \
        libxslt1.1 \
        libmemcachedutil2 \
# Required by eZ Commerce
        imagemagick \
# Python
        python3 \
        python3-pip \
# git & unneeded for composer, unless we document to use dev image for composer install
# unzip needed due to https://github.com/composer/composer/issues/4471
	zip \
        unzip \
        git \
    && rm -rf /var/lib/apt/lists/*

# Install and configure php plugins
RUN set -xe \
    && buildDeps=" \
        $PHP_EXTRA_BUILD_DEPS \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libxpm-dev \
        libpng-dev \
        libicu-dev \
        libxslt1-dev \
        libmemcached-dev \
    " \
	&& apt-get update -q -y && apt-get install -q -y --no-install-recommends $buildDeps && rm -rf /var/lib/apt/lists/* \
# Extract php source and install missing extensions
    && docker-php-source extract \
    && docker-php-ext-configure mysqli --with-mysqli=mysqlnd \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/ --with-xpm-dir=/usr/include/ --enable-gd-jis-conv \
    && docker-php-ext-install exif gd bcmath mbstring intl xsl zip mysqli pdo_mysql xml soap sockets \
    && cp /usr/src/php/php.ini-production ${PHP_INI_DIR}/php.ini \
    \
# Install igbinary (for more efficient serialization in redis/memcached)
    && for i in $(seq 1 3); do pecl install -o igbinary && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && docker-php-ext-enable igbinary \
    \
# Install redis (manualy build in order to be able to enable igbinary)
    && for i in $(seq 1 3); do pecl install -o --nobuild redis && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/redis" \
    && phpize \
    && ./configure --enable-redis-igbinary \
    && make \
    && make install \
    && docker-php-ext-enable redis \
    && cd - \
    \
# Install xdebug (manualy build in order to be able to enable igbinary)
    && for i in $(seq 1 3); do pecl install -o --nobuild xdebug && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/xdebug" \
    && phpize \
    && ./configure --enable-xdebug-igbinary \
    && make \
    && make install \
    && docker-php-ext-enable xdebug \
    && cd - \
    \
# Install memcached (manualy build in order to be able to enable igbinary)
    && for i in $(seq 1 3); do echo no | pecl install -o --nobuild memcached && s=0 && break || s=$? && sleep 1; done; (exit $s) \
    && cd "$(pecl config-get temp_dir)/memcached" \
    && phpize \
    && ./configure --enable-memcached-igbinary \
    && make \
    && make install \
    && docker-php-ext-enable memcached \
    && cd - \
    \
# Delete source & builds deps so it does not hang around in layers taking up space
    && pecl clear-cache \
    && rm -Rf "$(pecl config-get temp_dir)/*" \
    && docker-php-source delete \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $buildDeps

# Set timezone
RUN echo "UTC" > /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata

# Set pid file to be able to restart php-fpm
RUN sed -i "s@^\[global\]@\[global\]\n\npid = /run/php-fpm.pid@" ${PHP_INI_DIR}-fpm.conf

# Create Composer directory (cache and auth files) & Get Composer
RUN mkdir -p $COMPOSER_HOME \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install phpmd and put binary into $PATH
RUN curl -sSLo phpmd.phar http://static.phpmd.org/php/latest/phpmd.phar \
    && chmod 755 phpmd.phar \
    && mv phpmd.phar /usr/local/bin/ \
    && ln -s /usr/local/bin/phpmd.phar /usr/local/bin/phpmd

# Install phpcpd and put binary into $PATH
RUN curl -sSLo phpcpd.phar https://phar.phpunit.de/phpcpd.phar \
    && chmod 755 phpcpd.phar \
    && mv phpcpd.phar /usr/local/bin/ \
    && ln -s /usr/local/bin/phpcpd.phar /usr/local/bin/phpcpd

# Install phpunit and put binary into $PATH
RUN curl -sSLo phpunit.phar https://phar.phpunit.de/phpunit-6.5.9.phar \
    && chmod 755 phpunit.phar \
    && mv phpunit.phar /usr/local/bin/ \
    && ln -s /usr/local/bin/phpunit.phar /usr/local/bin/phpunit

# Install PHP Code sniffer
RUN curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcs.phar \
    && chmod 755 phpcs.phar \
    && mv phpcs.phar /usr/local/bin/ \
    && ln -s /usr/local/bin/phpcs.phar /usr/local/bin/phpcs \
    && curl -OL https://squizlabs.github.io/PHP_CodeSniffer/phpcbf.phar \
    && chmod 755 phpcbf.phar \
    && mv phpcbf.phar /usr/local/bin/ \
    && ln -s /usr/local/bin/phpcbf.phar /usr/local/bin/phpcbf

# Install PHP Deployer
RUN curl -LO https://deployer.org/deployer.phar \
    && mv deployer.phar /usr/local/bin/dep \
    && chmod +x /usr/local/bin/dep

# Install security checker
RUN php -r "readfile('http://get.sensiolabs.org/security-checker.phar');" > /usr/local/bin/security-checker \
    && chmod +x /usr/local/bin/security-checker
    
ENV DOCKERVERSION=17.12.0-ce
RUN curl -fsSLO https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKERVERSION}.tgz \
  && mv docker-${DOCKERVERSION}.tgz docker.tgz \
  && tar xzvf docker.tgz \
  && mv docker/docker /usr/local/bin \
  && rm -r docker docker.tgz
RUN curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose
RUN base=https://github.com/docker/machine/releases/download/v0.14.0 && \
    curl -L $base/docker-machine-$(uname -s)-$(uname -m) > /tmp/docker-machine && \
    install /tmp/docker-machine /usr/local/bin/docker-machine

# As application is put in as volume we do all needed operation on run
COPY scripts /scripts

# Add some custom config
COPY conf.d/php.ini ${PHP_INI_DIR}/conf.d/php.ini

RUN chmod 755 /scripts/*.sh

# Needed for docker-machine
RUN usermod -u 1000 www-data

WORKDIR /var/www

ENTRYPOINT ["/scripts/docker-entrypoint.sh"]

CMD php-fpm

EXPOSE 9000
