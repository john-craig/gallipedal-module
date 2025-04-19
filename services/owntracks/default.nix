{
  containers = {
    "otrecorder" = {
      image = "owntracks/recorder";
      environment = [
        "OTR_HTTPPORT"
        "OTR_HTTPHOST"
        "OTR_PORT"
      ];
      volumes = [
        {
          containerPath = "/config";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/store";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "8083";
          protocol = "tcp";
        }
        {
          containerPort = "8084";
          protocol = "tcp";
        }
      ];
      proxies = [
        {
          hostname = "owntracks.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
