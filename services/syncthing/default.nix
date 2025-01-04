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
        }
        {
          containerPath = "/sync/media";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/sync/programming";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/config";
          mountOptions = "rw";
          volumeType = "directory";
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

          external = true;
          internal = true;
        }
      ];

      extraOptions = [ ];
    };

  };
}
