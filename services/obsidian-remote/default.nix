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
        }
        {
          containerPath = "/vaults/main";
          mountOptions = "rw";
          volumeType = "directory";
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

          external = true;
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
