{
  containers = {
    "audiobookshelf" = {
      image = "ghcr.io/advplyr/audiobookshelf:latest";

      volumes = [
        {
          containerPath = "/config";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/metadata";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/audiobooks";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/podcasts";
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
          hostname = "audiobookshelf.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];
      
      extraOptions = [ ];
    };        
  };
}