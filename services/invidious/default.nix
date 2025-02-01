{
  containers = {
    "invidious" = {
      image = "quay.io/invidious/invidious:latest";
      volumes = [
        {
          containerPath = "/invidious/config/config.yml";
          mountOptions = "rw";
          # mountOptions = "rw,z";
          volumeType = "file";
        }
      ];
      ports = [
        {
          containerPort = "3001";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "invidious.chiliahedron.wtf";
          containerPort = "3001";

          external = true;
          internal = true;
        }
      ];

      dependsOn = [
        "invidious-invidious-db"
      ];

      extraOptions = [ ];
    };
    "invidious-db" = {
      image = "docker.io/library/postgres:14";
      environment = [
        "POSTGRES_DB"
        "POSTGRES_USER"
      ];
      secrets = [
        "POSTGRES_PASSWORD"
      ];
      volumes = [
        {
          containerPath = "/config/sql";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/var/lib/postgresql/data";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "999";
          volumeGroup = "999";
        }
        {
          containerPath = "/docker-entrypoint-initdb.d/init-invidious-db.sh";
          mountOptions = "rw";
          volumeType = "file";
        }
      ];

      extraOptions = [ ];
    };

  };
}
