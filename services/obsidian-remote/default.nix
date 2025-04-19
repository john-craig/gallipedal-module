{
  containers = {
    "obsidian-remote" = {
      image = "ghcr.io/sytone/obsidian-remote:latest";

      environment = [
        "DOCKER_MODS"
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
          containerPath = "/vaults/main";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];

      ports = [
        {
          containerPort = "8080";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "obsidian.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
