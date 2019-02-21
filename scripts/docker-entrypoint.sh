#!/usr/bin/env sh

set -e

# docker-entrypoint-initdb.d, as provided by most official images allows for direct usage and extended images to
# extend behaviour without modifying this file.
for f in /docker-entrypoint-initdb.d/*; do
    case "$f" in
        *.sh)     logger "$0: running $f"; . "$f" ;;
        "/docker-entrypoint-initdb.d/*") ;;
        *)        logger "$0: ignoring $f" ;;
    esac
done

# Scan for environment variables prefixed with PHP_INI_ENV_ and inject those into ${PHP_INI_DIR}/conf.d/zzz_custom_settings.ini
if [ -f ${PHP_INI_DIR}/conf.d/zzz_custom_settings.ini ]; then rm ${PHP_INI_DIR}/conf.d/zzz_custom_settings.ini; fi
env | while IFS='=' read -r name value ; do
  if (echo $name|grep -E "^PHP_INI_ENV">/dev/null); then
    # remove PHP_INI_ENV_ prefix
    name=`echo $name | cut -f 4- -d "_"`
    echo $name=$value >> ${PHP_INI_DIR}/conf.d/zzz_custom_settings.ini
  fi
done

exec "$@"