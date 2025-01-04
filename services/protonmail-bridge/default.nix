{
  containers = {
    "offlineimap" = {
      image = "cryptopath/offlineimap";
      environment = [
        "CRON_SCHEDULE"
      ];

      volumes = [
        {
          containerPath = "/vol/config";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/vol/mail";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/vol/secrets";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];

      extraOptions = [ ];
    };

    "bridge" = {
      image = "shenxn/protonmail-bridge";
      volumes = [
        {
          containerPath = "/root";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "25";
          protocol = "tcp";
        }
        {
          containerPort = "143";
          protocol = "tcp";
        }
      ];

      extraOptions = [ ];
    };
  };
}
