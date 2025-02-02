{
  containers = {
    "registry" = {
      image = "registry:2";

      volumes = [
        {
          containerPath = "/var/lib/registry";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];

      ports = [
        {
          containerPort = "5000";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "registry.chiliahedron.wtf";

          external = true;
          internal = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
