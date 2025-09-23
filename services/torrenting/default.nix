{
  containers = {
    # "protonwire" = {
    #   image = "ghcr.io/tprasadtp/protonwire:latest";

    #   secrets = [
    #     "WIREGUARD_PRIVATE_KEY"
    #   ];

    #   environment = [
    #     "PROTONVPN_SERVER"
    #     "KILL_SWITCH"
    #     "DEBUG"
    #   ];

    #   volumes = [ ];

    #   ports = [
    #     { # Prowlarr
    #       containerPort = "9696";
    #       protocol = "tcp";
    #     }
    #     { # Radarr
    #       containerPort = "7878";
    #       protocol = "tcp";
    #     }
    #     { # Sonarr
    #       containerPort = "8989";
    #       protocol = "tcp";
    #     }
    #     { # Lidarr
    #       containerPort = "8686";
    #       protocol = "tcp";
    #     }
    #   ];

    #   proxies = [
    #     {
    #       hostname = "prowlarr.chiliahedron.wtf";
    #       containerPort = "9696";
    #       external = false; # Temporarily disabled
    #       internal = true;
    #     }
    #     {
    #       hostname = "radarr.chiliahedron.wtf";
    #       containerPort = "7878";
    #       external = false; # Temporarily disabled
    #       internal = true;
    #     }
    #     {
    #       hostname = "sonarr.chiliahedron.wtf";
    #       containerPort = "8989";
    #       external = false; # Temporarily disabled
    #       internal = true;
    #     }
    #     {
    #       hostname = "lidarr.chiliahedron.wtf";
    #       containerPort = "8686";
    #       external = false; # Temporarily disabled
    #       internal = true;
    #     }
    #   ];

    #   extraOptions = [
    #     "--network=bridge"
    #     "--cap-add=NET_ADMIN"
    #     "--sysctl=net.ipv4.conf.all.rp_filter=2"
    #     "--tmpfs=/tmp"
    #   ];
    # };

    "wireguard" = {
      image = "ghcr.io/wfg/wireguard";

      environment = [
        "ALLOWED_SUBNETS"
      ];

      volumes = [ {
        containerPath = "/etc/wireguard";
        mountOptions = "rw";
        volumeType = "directory";
        volumeOwner = "1000";
        volumeGroup = "1000";
      } ];

      ports = [
        { # Prowlarr
          containerPort = "9696";
          protocol = "tcp";
        }
        { # Radarr
          containerPort = "7878";
          protocol = "tcp";
        }
        { # Sonarr
          containerPort = "8989";
          protocol = "tcp";
        }
        { # Lidarr
          containerPort = "8686";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "prowlarr.chiliahedron.wtf";
          containerPort = "9696";
          external = false; # Temporarily disabled
          internal = true;
        }
        {
          hostname = "radarr.chiliahedron.wtf";
          containerPort = "7878";
          external = false; # Temporarily disabled
          internal = true;
        }
        {
          hostname = "sonarr.chiliahedron.wtf";
          containerPort = "8989";
          external = false; # Temporarily disabled
          internal = true;
        }
        {
          hostname = "lidarr.chiliahedron.wtf";
          containerPort = "8686";
          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [
        "--cap-add=NET_ADMIN"
        "--sysctl=net.ipv4.conf.all.rp_filter=2"
      ];

    };
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
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];

      ports = [ ];

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
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/movies";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/downloads/radarr";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];

      ports = [ ];

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
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/tv";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/downloads/sonarr";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];

      ports = [ ];

      extraOptions = [ ];
    };

    "lidarr" = {
      image = "linuxserver/lidarr:latest";

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
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/music";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/downloads/lidarr";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];

      ports = [ ];

      extraOptions = [ ];
    };

    "lidatube" = {
      image = "thewicklowwolf/lidatube:latest";

      environment = [
        "lidarr_address" # The URL for Lidarr. Defaults to http://192.168.1.2:8686.
        "attempt_lidarr_import" # Attempt to import each song directly into Lidarr. Defaults to False.
        # lidarr_api_timeout: Timeout duration for Lidarr API calls. Defaults to 120.
        # thread_limit: Max number of threads to use. Defaults to 1.
        # sleep_interval: Interval to sleep. Defaults to 0.
        # fallback_to_top_result: Whether to use the top result if no match is found. Defaults to False.
        # library_scan_on_completion: Whether to scan Lidarr Library on completion. Defaults to True.
        # sync_schedule: Schedule times to run (comma seperated values in 24hr). Defaults to ``
        # minimum_match_ratio: Minimum percentage for a match. Defaults to 90
        # secondary_search: Method for secondary search (YTS or YTDLP). Defaults to YTS.
        # preferred_codec: Preferred codec (mp3). Defaults to mp3.
      ];

      secrets = [
        "lidarr_api_key" # The API key for Lidarr. Defaults to ``.
      ];

      volumes = [
        {
          containerPath = "/lidatube/config";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/lidatube/downloads";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        # {
        #   containerPath = "/etc/localtime";
        #   mountOptions = "ro";
        #   volumeType = "file";
        # }
      ];

      ports = [
        {
          containerPort = "5000";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "lidatube.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };

    "yt-dlp-webui" = {
      image = "marcobaobao/yt-dlp-webui";

      volumes = [
        {
          containerPath = "/downloads";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];

      ports = [
        {
          containerPort = "3033";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "yt-dlp.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
