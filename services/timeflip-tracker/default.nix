{
  containers = {
    "tracker" = {
      image = "registry.chiliahedron.wtf/john-craig/timeflip-tracker";
      environment = [
        "LOG_LEVEL"
        "MARIADB_DATABASE"
        "MARIADB_HOST"
        "MARIADB_PASSWORD"
        "MARIADB_PORT"
        "MARIADB_USER"
      ];
      volumes = [
        {
          containerPath = "/etc/timeflip-tracker/config.yaml";
          mountOptions = "rw";
          volumeType = "file";
        }
        {
          containerPath = "/var/run/dbus";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      
      dependsOn = [
        "timeflip-tracker-database"
      ];
    };

    "database" = {
      image = "mariadb:latest";
      environment = [
        "MARIADB_DATABASE"
        "MARIADB_PASSWORD"
        "MARIADB_RANDOM_ROOT_PASSWORD"
        "MARIADB_USER"
      ];

      volumes = [
        {
          containerPath = "/var/lib/mysql";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "3306";
          protocol = "tcp";
        }
      ];
      
      networks = {
        external = true;
      };
    };
  };
}
