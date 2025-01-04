{
  containers = {
    "prowlarr" = {
      image = "lscr.io/linuxserver/prowlarr:latest";

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
          containerPort = "9696";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "prowlarr.chiliahedron.wtf";

          external = true;
          internal = true;
        }
      ];

      extraOptions = [ ];
    };

    "radarr" = {
      image = "linuxserver/radarr:latest";

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
        {
          containerPath = "/movies";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/downloads/radarr";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];

      ports = [
        {
          containerPort = "7878";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "radarr.chiliahedron.wtf";

          external = true;
          internal = true;
        }
      ];

      extraOptions = [ ];
    };


    "sonarr" = {
      image = "linuxserver/sonarr:latest";

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
        {
          containerPath = "/tv";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/downloads/sonarr";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];

      ports = [
        {
          containerPort = "8989";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "sonarr.chiliahedron.wtf";

          external = true;
          internal = true;
        }
      ];

      extraOptions = [ ];
    };

    "resilio" = {
      image = "nimmis/resilio-sync:latest";

      environment = [
        "RSLSYNC_TRASH_TIME"
        "RSLSYNC_SIZE"
        "PGID"
        "PUID"
        "TZ"
        "STORAGE_DIR"
      ];

      secrets = [
        "RSLSYNC_SECRET"
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
          containerPort = "8888";
          protocol = "tcp";
        }
        {
          containerPort = "33333";
          protocol = "tcp";
        }
      ];

      proxies = [ ];

      extraOptions = [ ];
    };
  };
}
