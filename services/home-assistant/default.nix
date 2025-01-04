{
  containers = {
    "hass" = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      volumes = [
        {
          containerPath = "/etc/localtime";
          mountOptions = "ro";
          volumeType = "file";
        }
        {
          containerPath = "/config";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [{
        containerPort = "8123";
        protocol = "tcp";
      }];

      proxies = [
        {
          hostname = "homeassistant.chiliahedron.wtf";
          containerPort = "8123";

          external = true;
          internal = true;
        }
      ];

      networks = { };

      extraOptions = [ "--privileged" ];
    };

  };
}
