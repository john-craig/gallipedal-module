{
  containers = {
    "code-server" = {
      image = "lscr.io/linuxserver/code-server:latest";
      environment = [
        "DEFAULT_WORKSPACE"
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
          containerPath = "/programming";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "8443";
          protocol = "tcp";
        }
      ];

      extraOptions = [ ];
    };
  };
}
