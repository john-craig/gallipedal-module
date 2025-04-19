{
  containers = {
    "infisical-backend" = {
      image = "infisical/infisical:latest";
      environment = {
        NODE_ENV = "production";
      };
      ports = [
        {
          hostPort = "4010";
          containerPort = "8080";
          protocol = "tcp";
        }
      ];
      proxies = [
        {

          hostname = "infisical.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;

        }
      ];
      dependsOn = [
        "infisical-infisical-mongo"
      ];

      extraOptions = [ ];
    };
    "infisical-dev-redis" = {
      image = "redis";
      environment = {
        ALLOW_EMPTY_PASSWORD = "True";
      };
      volumes = [
        {
          hostPath = "/opt/infisical/redis/data";
          containerPath = "/srv";
          mountOptions = "rw";
        }
      ];
      ports = [
        {
          hostPort = "4011";
          containerPort = "6379";
          protocol = "tcp";
        }
      ];
      labels = { };

      extraOptions = [ ];
    };
    "infisical-mongo" = {
      image = "mongo:4.4.6";
      environment = {
        MONGO_INITDB_DATABASE = "infisical";
        MONGO_INITDB_ROOT_PASSWORD = "example";
        MONGO_INITDB_ROOT_USERNAME = "root";
      };
      volumes = [
        {
          hostPath = "/opt/infisical/mongo/data";
          containerPath = "/srv/db";
          mountOptions = "rw";
        }
      ];
      ports = [
        {
          hostPort = "4012";
          containerPort = "27017";
          protocol = "tcp";
        }
      ];
      cmd = [ "--bind_ip_all" ];
      labels = { };

      extraOptions = [ ];
    };

  };
}
