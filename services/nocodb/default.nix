{
  containers = {
    "nocodb" = {
      image = "nocodb/nocodb:latest";
      secrets = [
        "NC_DB"
      ];
      volumes = [
        {
          containerPath = "/usr/app/data";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "8080";
          protocol = "tcp";
        }
      ];
      proxies = [
        {
          hostname = "nocodb.chiliahedron.wtf";

          external = true;
          internal = true;
        }
      ];

      dependsOn = [ "nocodb-root_db" ];

      extraOptions = [
        
      ];
    };
    "root_db" = {
      image = "postgres:16.6";
      environment = [
        "POSTGRES_DB"
        "POSTGRES_USER"
      ];
      secrets = [
        "POSTGRES_PASSWORD"
      ];
      volumes = [
        {
          containerPath = "/var/lib/postgresql/data";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];

      extraOptions = [
        
      ];
    };
  };
}
