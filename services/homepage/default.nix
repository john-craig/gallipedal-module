{
  containers = {
    "homepage" = {
      image = "ghcr.io/gethomepage/homepage:latest";
      volumes = [
        {
          containerPath = "/app/config";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "3000";
          protocol = "tcp";
        }
      ];
      proxies = [
        {
          hostname = "chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
