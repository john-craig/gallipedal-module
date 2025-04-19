{
  containers = {
    "grocy" = {
      image = "lscr.io/linuxserver/grocy:latest";
      environment = [
        "PGID"
        "PUID"
        "TZ"
      ];
      volumes = [
        {
          containerPath = "/config";
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
          hostname = "grocy.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
