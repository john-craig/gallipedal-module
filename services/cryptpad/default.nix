{
  containers = {
    "cryptpad" = {
      image = "cryptpad/cryptpad:version-2024.6.1";

      environment = {
        CPAD_MAIN_DOMAIN = "https://cryptpad.chiliahedron.wtf";
        CPAD_SANDBOX_DOMAIN = "https://cryptpad.sandbox.chiliahedron.wtf";
        CPAD_CONF = "/cryptpad/config/config.js";
        CPAD_INSTALL_ONLYOFFICE = "yes";
      };

      volumes = [
        {
          hostPath = "/srv/container/cryptpad/config/config.js";
          containerPath = "/cryptpad/config/config.js";
          mountOptions = "rw";
          volumeType = "file";
        }
        {
          hostPath = "/srv/container/cryptpad/data/blob";
          containerPath = "/cryptpad/blob";
          mountOptions = "rw";
        }
        {
          hostPath = "/srv/container/cryptpad/data/blob";
          containerPath = "/cryptpad/blob";
          mountOptions = "rw";
        }
        {
          hostPath = "/srv/container/cryptpad/data/block";
          containerPath = "/cryptpad/block";
          mountOptions = "rw";
        }
        {
          hostPath = "/srv/container/cryptpad/customize";
          containerPath = "/cryptpad/customize";
          mountOptions = "rw";
        }
        {
          hostPath = "/srv/container/cryptpad/data/data";
          containerPath = "/cryptpad/data";
          mountOptions = "rw";
        }
        {
          hostPath = "/srv/container/cryptpad/data/files";
          containerPath = "/cryptpad/datastore";
          mountOptions = "rw";
        }
        {
          hostPath = "/srv/container/cryptpad/onlyoffice-dist";
          containerPath = "/cryptpad/www/common/onlyoffice/dist";
          mountOptions = "rw";
        }
        {
          hostPath = "/srv/container/cryptpad/onlyoffice-conf";
          containerPath = "/cryptpad/onlyoffice-conf";
          mountOptions = "rw";
        }
      ];
      ports = [
        {
          hostPort = "3010";
          containerPort = "3000";
          protocol = "tcp";
        }
        {
          hostPort = "3014";
          containerPort = "3003";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostnames = [
            "cryptpad.chiliahedron.wtf"
            "cryptpad.sandbox.chiliahedron.wtf"
          ];
          containerPort = "3000";

          external = true;
          internal = true;
        }
        {
          hostnames = [
            "cryptpad.chiliahedron.wtf"
            "cryptpad.sandbox.chiliahedron.wtf"
          ];
          containerPort = "3003";
          pathPrefix = "/cryptpad_websocket";

          external = true;
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
