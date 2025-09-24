{
  containers = {
    "gotify" = {
      image = "gotify/server";
      secrets = [
        "GOTIFY_DEFAULTUSER_PASS"
      ];
      volumes = [
        {
          containerPath = "/app/data";
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

      extraOptions = [
        "--network-alias=gotify"
        "--network=chiliahedron-services"
      ];
    };

  };
}
