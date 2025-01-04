{
  containers = {
    "freepbx" = {
      image = "flaviostutz/freepbx";
      environment = {
        ADMIN_PASSWORD = "admin123";
      };
      volumes = [
        {
          hostPath = "/srv/container/freepbx/backup";
          containerPath = "/backup";
          mountOptions = "rw";
        }
        {
          hostPath = "/srv/container/freepbx/backup";
          containerPath = "/var/spool/asterisk/monitor";
          mountOptions = "rw";
        }
      ];
      ports = [
        {
          hostPort = "6797";
          containerPort = "80";
          protocol = "tcp";
        }
        {
          hostPort = "3306";
          containerPort = "3306";
          protocol = "tcp";
        }
        {
          hostPort = "5060";
          containerPort = "5060";
          protocol = "udp";
        }
        {
          hostPort = "5160";
          containerPort = "5160";
          protocol = "udp";
        }
        #- 18000-18100:18000-18100/udp
      ];
      proxies = [
        {
          hostname = "freepbx.chiliahedron.wtf";

          internal = true;
          external = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
