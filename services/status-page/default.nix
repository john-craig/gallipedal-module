{
  containers = {
    "httpd" = {
      image = "httpd:2.4";

      volumes = [
        {
          containerPath = "/usr/local/apache2/htdocs";
          mountOptions = "rw";
          volumeType = "directory";

          extraPerms = [
            {
              relPath = ".";
              permissions = "755";
            }
          ];
        }
      ];

      proxies = [
        {
          hostname = "status.chiliahedron.wtf";

          internal = true;
          external = true;

          containerPort = "80";
        }
      ];
    };
  };
}
