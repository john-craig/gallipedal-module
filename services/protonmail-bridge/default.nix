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

          extraPerms = [
            {
              relPath = "metadata";
              permissions = "777";
            }
            {
              relPath = "email";
              permissions = "777";
            }
          ];
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

          extraPerms = [
            {
              relPath = ".";
              permissions = "777";
            }
          ];
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
