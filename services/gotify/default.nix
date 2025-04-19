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
      proxies = [
        {
          hostname = "gotify.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [
        "--network-alias=gotify"
        "--network=chiliahedron-services"
      ];
    };

  };
}
