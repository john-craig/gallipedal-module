{
  containers = {
    "onlyoffice" = {
      image = "onlyoffice/documentserver";
      environment = {
        JWT_SECRET = "SBKOvlGl094jnGmwqgREeQpcQYG3XvJl";
      };
      volumes = [
        {
          hostPath = "/srv/container/onlyoffice/data";
          containerPath = "/var/www/onlyoffice/Data";
          mountOptions = "rw";
        }
        {
          hostPath = "/srv/container/onlyoffice/logs";
          containerPath = "/var/log/onlyoffice";
          mountOptions = "rw";
        }
      ];
      ports = [
        {
          hostPort = "5666";
          containerPort = "80";
          protocol = "tcp";
        }
      ];
      proxies = [
        {

          hostname = "onlyoffice.chiliahedron.wtf";

          external = true;
          internal = true;

        }
      ];

      extraOptions = [ ];
    };
  };
}
