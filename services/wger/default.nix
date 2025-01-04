{
  containers = {
    "wger-app" = {
      image = "wger/server:latest";

      environment = { };

      volumes = [
        {
          hostPath = "/srv/container/wger/app/static";
          containerPath = "/home/wger/static";
          mountOptions = "rw";

          extraPerms = [{
            relPath = "/";
            permissions = "777";
          }];
        }
      ];

      networks = {
        external = true;
      };

      dependsOn = [ "wger-wger-db" "wger-wger-cache" ];

      ports = [ ];

      extraOptions = [ ];
    };

    "wger-proxy" = {
      image = "nginx:stable";

      volumes = [
        {
          hostPath = "/srv/container/wger/proxy/nginx.conf";
          containerPath = "/etc/nginx/conf.d/default.conf";
          mountOptions = "ro";
        }
        {
          hostPath = "/srv/container/wger/app/static";
          containerPath = "/wger/static";
          mountOptions = "ro";
        }
        {
          hostPath = "/srv/container/wger/app/media";
          containerPath = "/wger/media";
          mountOptions = "ro";
        }
      ];

      ports = [
        {
          hostPort = "8171";
          containerPort = "80";
          protocol = "tcp";
        }
      ];

      proxies = [
        {

          hostname = "wger.chiliahedron.wtf";

          external = true;
          internal = true;

        }
      ];
    };

    "wger-db" = {
      image = "postgres:15-alpine";

      environment = {
        "POSTGRES_USER" = "wger";
        "POSTGRES_PASSWORD" = "wger";
        "POSTGRES_DB" = "wger";
      };

      volumes = [
        {
          hostPath = "/srv/container/wger/data";
          containerPath = "/var/lib/postgresql/data";
          mountOptions = "rw";
        }
      ];

      extraOptions = [ ];
    };

    "wger-cache" = {
      image = "redis";

      environment = { };

      volumes = [
        {
          hostPath = "/srv/container/wger/cache";
          containerPath = "/data";
          mountOptions = "rw";
        }
      ];

      extraOptions = [ ];
    };

    "celery-worker" = {
      image = "wger/server:latest";

      environment = { };

      volumes = [
        {
          hostPath = "/srv/container/wger/app/media";
          containerPath = "/home/wger/media";
          mountOptions = "rw";
        }
      ];

      dependsOn = [ "wger-wger-app" ];

      cmd = [ "/start-worker" ];

      extraOptions = [ ];
    };

    "celery-beat" = {
      image = "wger/server:latest";

      environment = { };

      volumes = [
        {
          hostPath = "/srv/container/wger/app/beat";
          containerPath = "/home/wger/beat";
          mountOptions = "rw";
        }
      ];

      dependsOn = [ "wger-celery-worker" ];

      cmd = [ "/start-beat" ];

      extraOptions = [ ];
    };

  };

  environment = {
    # Django's secret key, change to a 50 character random string if you are running
    # this instance publicly. For an online generator, see e.g. https://djecrety.ir/
    SECRET_KEY = "wger-docker-supersecret-key-1234567890!@#$%^&*(-_)";

    # Signing key used for JWT, use something different than the secret key
    SIGNING_KEY = "wger-docker-secret-jwtkey-1234567890!@#$%^&*(-_=+)";

    # The server's timezone, for a list of possible names:
    # https://en.wikipedia.org/wiki/List_of_tz_database_time_zones
    TIME_ZONE = "America/New_York";

    #
    # Consult the deployment section in the readme if you are running this behind a
    # reverse proxy with HTTPS enabled

    # CSRF_TRUSTED_ORIGINS = "https://my.domain.example.com,https://118.999.881.119";
    # X_FORWARDED_PROTO_HEADER_SET = "True";

    #
    # Static files
    # If you are running the application behind a reverse proxy or changed the port, the
    # links for some images *might* break (specially in the mobile app). Also note that
    # the API response is cached and contains the host, if you change this setting, just run
    # docker compose exec web python3 manage.py warmup-exercise-api-cache --force
    # MEDIA_URL = "https://your-domain.example.com/media/";
    # STATIC_URL = "https://your-domain.example.com/static/";

    #
    # These settings usually don't need changing
    #

    #
    # Application
    WGER_INSTANCE = "https://wger.de"; # Wger instance from which to sync exercises, images, etc.
    ALLOW_REGISTRATION = "True";
    ALLOW_GUEST_USERS = "True";
    ALLOW_UPLOAD_VIDEOS = "True";
    # Users won't be able to contribute to exercises if their account age is
    # lower than this amount in days.
    MIN_ACCOUNT_AGE_TO_TRUST = "1";
    # Synchronzing exercises
    # It is recommended to keep the local database synchronized with the wger
    # instance specified in WGER_INSTANCE since there are new added or translations
    # improved. For this you have different possibilities:
    # - Sync exercises on startup:
    # SYNC_EXERCISES_ON_STARTUP = "True";
    # DOWNLOAD_EXERCISE_IMAGES_ON_STARTUP = "True";
    # - Sync them in the background with celery. This will setup a job that will run
    #   once a week at a random time (this time is selected once when starting the server)
    SYNC_EXERCISES_CELERY = "True";
    SYNC_EXERCISE_IMAGES_CELERY = "True";
    SYNC_EXERCISE_VIDEOS_CELERY = "True";
    # - Manually trigger the process as needed:
    #   docker compose exec web python3 manage.py sync-exercises
    #   docker compose exec web python3 manage.py download-exercise-images
    #   docker compose exec web python3 manage.py download-exercise-videos

    # Synchronzing ingredients
    # You can also syncronize the ingredients from a remote wger instance, and have
    # basically the same options as for the ingredients:
    # - Sync them in the background with celery. This will setup a job that will run
    #   once a week at a random time (this time is selected once when starting the server)
    SYNC_INGREDIENTS_CELERY = "True";
    # - Manually trigger the process as needed:
    #   docker compose exec web python3 manage.py sync-ingredients

    # When scanning products with the barcode scanner, it is possible to dynamically
    # fetch the ingredient if it is not known in the local database. This option controlls
    # where to try to download the ingredient and their images.
    # Possible values OFF, WGER or None. Note that it is recommended to keep this as WGER
    # so that we don't overwhelm the Open Food Facts servers. Needs to have USE_CELERY
    # set to true
    DOWNLOAD_INGREDIENTS_FROM = "WGER";

    # Whether celery is configured and should be used. Can be left to true with
    # this setup but can be deactivated if you are using the app in some other way
    USE_CELERY = "True";

    #
    # Celery
    CELERY_BROKER = "redis://cache:6379/2";
    CELERY_BACKEND = "redis://cache:6379/2";
    CELERY_FLOWER_PASSWORD = "adminadmin";

    #
    # Database
    DJANGO_DB_ENGINE = "django.db.backends.postgresql";
    DJANGO_DB_DATABASE = "wger";
    DJANGO_DB_USER = "wger";
    DJANGO_DB_PASSWORD = "wger";
    DJANGO_DB_HOST = "wger-wger-db";
    DJANGO_DB_PORT = "5432";
    DJANGO_PERFORM_MIGRATIONS = "True"; # Perform any new database migrations on startup

    #
    # Cache
    DJANGO_CACHE_BACKEND = "django_redis.cache.RedisCache";
    DJANGO_CACHE_LOCATION = "redis://wger-wger-cache:6379/1";
    DJANGO_CACHE_TIMEOUT = "1296000"; # in seconds - 60*60*24*15, 15 Days
    DJANGO_CACHE_CLIENT_CLASS = "django_redis.client.DefaultClient";
    # DJANGO_CACHE_CLIENT_PASSWORD = "abcde... # Only if you changed the redis config";
    # DJANGO_CACHE_CLIENT_SSL_KEYFILE = "/path/to/ssl_keyfile # Path to an ssl private key.";
    # DJANGO_CACHE_CLIENT_SSL_CERTFILE = "/path/to/ssl_certfile # Path to an ssl certificate.";
    # DJANGO_CACHE_CLIENT_SSL_CERT_REQS = "<none | optional | required> # The string value for the verify_mode.";
    # DJANGO_CACHE_CLIENT_SSL_CHECK_HOSTNAME = "False # If set, match the hostname during the SSL handshake.";

    #
    # Brute force login attacks
    # https://django-axes.readthedocs.io/en/latest/index.html
    AXES_ENABLED = "True";
    AXES_FAILURE_LIMIT = "10";
    AXES_COOLOFF_TIME = "30"; # in minutes
    AXES_HANDLER = "axes.handlers.cache.AxesCacheHandler";
    AXES_LOCKOUT_PARAMETERS = "ip_address";
    AXES_IPWARE_PROXY_COUNT = "1";
    AXES_IPWARE_META_PRECEDENCE_ORDER = "HTTP_X_FORWARDED_FOR,REMOTE_ADDR";
    #
    # Others
    DJANGO_DEBUG = "False";
    WGER_USE_GUNICORN = "True";
    EXERCISE_CACHE_TTL = "18000"; # in seconds - 5*60*60, 5 hours
    SITE_URL = "http://localhost";

    #
    # JWT auth
    ACCESS_TOKEN_LIFETIME = "10"; # The lifetime duration of the access token, in minutes
    REFRESH_TOKEN_LIFETIME = "24"; # The lifetime duration of the refresh token, in hours

    #
    # Other possible settings

    # Recaptcha keys. You will need to create an account and register your domain
    # https://www.google.com/recaptcha/
    # RECAPTCHA_PUBLIC_KEY = "abcde...";
    # RECAPTCHA_PRIVATE_KEY = "abcde...";
    USE_RECAPTCHA = "False";

    # Clears the static files before copying the new ones (i.e. just calls collectstatic
    # with the appropriate flag: "manage.py collectstatic --no-input --clear"). Usually
    # This can be left like this but if you have problems and new static files are not
    # being copied correctly, clearing everything might help
    DJANGO_CLEAR_STATIC_FIRST = "False";

    #
    # Email
    # https://docs.djangoproject.com/en/4.1/topics/email/#smtp-backend
    # ENABLE_EMAIL = "False";
    # EMAIL_HOST = "email.example.com";
    # EMAIL_PORT = "587";
    # EMAIL_HOST_USER = "username";
    # EMAIL_HOST_PASSWORD = "password";
    # EMAIL_USE_TLS = "True";
    # EMAIL_USE_SSL = "False";
    FROM_EMAIL = "'wger Workout Manager <wger@example.com>'";

    # Set your name and email to be notified if an internal server error occurs.
    # Needs a working email configuration
    # DJANGO_ADMINS = "your name,email@example.com";

    # Whether to compress css and js files into one (of each)
    # COMPRESS_ENABLED = "True";

    #
    # Django Rest Framework
    # The number of proxies in front of the application. In the default configuration only nginx
    # is. Change as approtriate if your setup differs
    NUMBER_OF_PROXIES = "2";
  };
}
