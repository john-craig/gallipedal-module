{
  containers = {
    "vaultwarden" = {
      image = "vaultwarden/server:latest";

      environment = [
        "DOMAIN"
      ];

      volumes = [
        {
          containerPath = "/data";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];

      ports = [
        {
          containerPort = "80";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "vaultwarden.chiliahedron.wtf";

          external = true;
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
