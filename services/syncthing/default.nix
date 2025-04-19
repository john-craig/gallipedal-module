{
  containers = {
    "syncthing" = {
      image = "linuxserver/syncthing";
      environment = [
        "PGID"
        "PUID"
        "TZ"
        "UMASK_SET"
      ];
      volumes = [
        {
          containerPath = "/sync/documents";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/sync/media";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/sync/programming";
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
        }
      ];
      ports = [
        {
          containerPort = "8384";
          protocol = "tcp";
        }
        {
          containerPort = "22000";
          protocol = "tcp";
        }
        {
          containerPort = "21027";
          protocol = "udp";
        }
      ];
      proxies = [
        {
          hostname = "syncthing.chiliahedron.wtf";

          containerPort = "8384";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };

  };
}
