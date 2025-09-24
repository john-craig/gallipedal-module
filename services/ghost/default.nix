{
  containers = {
    # "caddy" = {
    #   image = "caddy:2.10.0-alpine@sha256:e2e3a089760c453bc51c4e718342bd7032d6714f15b437db7121bfc2de2654a6";
    #   environment = [
    #     "DOMAIN"
    #     "ADMIN_DOMAIN"
    #     "ACTIVITYPUB_TARGET"
    #   ];
    #   volumes = [
    #     {
    #       containerPath = "/etc/caddy";
    #       mountOptions = "rw";
    #       volumeType = "directory";
    #     }
    #     {
    #       containerPath = "/data";
    #       mountOptions = "rw";
    #       volumeType = "directory";
    #     }
    #     {
    #       containerPath = "/config";
    #       mountOptions = "rw";
    #       volumeType = "directory";
    #     }
    #   ];
    #   ports = [
    #     { containerPort = "80"; protocol = "tcp"; }
    #     { containerPort = "443"; protocol = "tcp"; }
    #   ];
    # };

    "ghost" = {
      image = "ghost:6-alpine";
      environment = [
        "NODE_ENV"
        "url"
        "admin__url"
        "database__client"
        "database__connection__host"
        "database__connection__user"
        "database__connection__database"
        "tinybird__tracker__endpoint"
        "tinybird__adminToken"
        "tinybird__workspaceId"
        "tinybird__tracker__datasource"
        "tinybird__stats__endpoint"
      ];
      secrets = [
        "database__connection__password"
      ];
      volumes = [
        {
          containerPath = "/var/lib/ghost/content";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        { containerPort = "2368"; protocol = "tcp"; }
      ];

      proxies = [
        {
          hostnames = [
            "ghost.chiliahedron.wtf"
            "ghost.admin.chiliahedron.wtf"
          ];

          external = false;
          internal = true;
        }
      ];
    };

    "db" = {
      image = "mysql:8.0.42@sha256:4445b2668d41143cb50e471ee207f8822006249b6859b24f7e12479684def5d9";
      environment = [
        "MYSQL_USER"
        "MYSQL_DATABASE"
        "MYSQL_MULTIPLE_DATABASES"
      ];
      secrets = [
        "MYSQL_ROOT_PASSWORD"
        "MYSQL_PASSWORD"
      ];
      volumes = [
        {
          containerPath = "/var/lib/mysql";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "999";
          volumeGroup = "999";
        }
        {
          containerPath = "/docker-entrypoint-initdb.d";
          mountOptions = "ro";
          volumeType = "directory";
          volumeOwner = "999";
          volumeGroup = "999";
        }
      ];
      ports = [
        { containerPort = "3306"; protocol = "tcp"; }
      ];
    };

    "traffic-analytics" = {
      image = "ghost/traffic-analytics:1.0.15@sha256:8d98e9f4eb623d1c7953d5a60b944db1850bc61ac4a6f637055d05b4a2be798f";
      environment = [
        "NODE_ENV"
        "PROXY_TARGET"
        "SALT_STORE_TYPE"
        "SALT_STORE_FILE_PATH"
        "TINYBIRD_TRACKER_TOKEN"
        "LOG_LEVEL"
      ];
      volumes = [
        {
          containerPath = "/data";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        { containerPort = "3000"; protocol = "tcp"; }
      ];
      proxies = [
        {
          hostnames = [
            "ghost.chiliahedron.wtf"
          ];
          pathPrefix = "/.ghost/analytics";
          external = false;
          internal = true;
        }
      ];
    };

    "activitypub" = {
      image = "ghcr.io/tryghost/activitypub:1.1.0@sha256:39c212fe23603b182d68e67d555c6b9b04b1e57459dfc0bef26d6e4980eb04d1";
      environment = [
        "NODE_ENV"
        "MYSQL_HOST"
        "MYSQL_USER"
        "MYSQL_DATABASE"
        "LOCAL_STORAGE_PATH"
        "LOCAL_STORAGE_HOSTING_URL"
      ];
      secrets = [
        "MYSQL_PASSWORD"
      ];
      volumes = [
        {
          containerPath = "/opt/activitypub/content";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        { containerPort = "8080"; protocol = "tcp"; }
      ];
    };

    # "tinybird-login" = {
    #   build = {
    #     context = "./tinybird";
    #     dockerfile = "Dockerfile";
    #   };
    #   command = ["/usr/local/bin/tinybird-login"];
    #   volumes = [
    #     {
    #       containerPath = "/home/tinybird";
    #       mountOptions = "rw";
    #       volumeType = "directory";
    #     }
    #     {
    #       containerPath = "/data/tinybird";
    #       mountOptions = "rw";
    #       volumeType = "directory";
    #     }
    #   ];
    # };

    # "tinybird-sync" = {
    #   image = "ghost:6-alpine";
    #   command = [
    #     "sh" "-c"
    #     "if [ -d /var/lib/ghost/current/core/server/data/tinybird ]; then rm -rf /data/tinybird/*; cp -rf /var/lib/ghost/current/core/server/data/tinybird/* /data/tinybird/; echo 'Tinybird files synced into shared volume.'; else echo 'Tinybird source directory not found.'; fi"
    #   ];
    #   volumes = [
    #     {
    #       containerPath = "/data/tinybird";
    #       mountOptions = "rw";
    #       volumeType = "directory";
    #     }
    #   ];
    # };

    # "tinybird-deploy" = {
    #   build = {
    #     context = "./tinybird";
    #     dockerfile = "Dockerfile";
    #   };
    #   command = [
    #     "sh" "-c" "tb-wrapper --cloud deploy"
    #   ];
    #   volumes = [
    #     {
    #       containerPath = "/home/tinybird";
    #       mountOptions = "rw";
    #       volumeType = "directory";
    #     }
    #     {
    #       containerPath = "/data/tinybird";
    #       mountOptions = "rw";
    #       volumeType = "directory";
    #     }
    #   ];
    # };

    "activitypub-migrate" = {
      image = "ghcr.io/tryghost/activitypub-migrations:1.1.0@sha256:b3ab20f55d66eb79090130ff91b57fe93f8a4254b446c2c7fa4507535f503662";
      secrets = [
        "MYSQL_DB"
      ];
    };
  };
}
