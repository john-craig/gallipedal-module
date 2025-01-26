{
  containers = {
    "jellyfin" = {
      image = "lscr.io/linuxserver/jellyfin:latest";
      environment = [
        "PGID"
        "PUID"
        "TZ"
      ];
      volumes = [
        {
          containerPath = "/cache";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/config";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";

          extraPerms = [
            {
              relPath = "data";
              permissions = "777";
            }
          ];
        }
        {
          containerPath = "/media";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "8096";
          protocol = "tcp";
        }
        {
          containerPort = "8920";
          protocol = "tcp";
        }
        {
          containerPort = "7359";
          protocol = "udp";
        }
        {
          containerPort = "1900";
          protocol = "udp";
        }
      ];

      proxies = [
        {
          hostname = "jellyfin.chiliahedron.wtf";

          containerPort = "8096";

          external = true;
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
