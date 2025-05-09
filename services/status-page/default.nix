{
  containers = {
    "httpd" = {
      image = "httpd:2.4";

      volumes = [
        {
          containerPath = "/usr/local/apache2/htdocs";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "33";
          volumeGroup = "33";

          # extraPerms = [
          #   {
          #     relPath = ".";
          #     permissions = "755";
          #   }
          # ];
        }
      ];

      proxies = [
        {
          hostname = "status.chiliahedron.wtf";

          internal = true;
          external = false; # Temporarily disabled

          containerPort = "80";
        }
      ];
    };
  };
}
