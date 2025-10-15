{
  containers = {
    "suivi-bourse" = {
      image = "ghcr.io/pbrissaud/suivi-bourse-app:latest";

      volumes = [
        {
          containerPath = "/home/appuser/.config/SuiviBourse/config.yaml";
          mountOptions = "ro";
          volumeType = "file";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];
      environment = [
        "SB_SCRAPING_INTERVAL"
        "LOG_LEVEL"
      ];
      ports = [{
        containerPort = "8081";
        protocol = "tcp";
      }];

      extraOptions = [ ];
    };
  };
}
