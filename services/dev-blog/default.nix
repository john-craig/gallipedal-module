{
  containers = {
    "dev-blog" = {
      image = "registry.chiliahedron.wtf/john-craig/gatsby-dev-blog:latest";
      volumes = [
        {
          containerPath = "/app/ext/pages/blog";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "9000";
          protocol = "tcp";
        }
      ];
      proxies = [
        {
          hostname = "john-craig.dev";
          public = true;
        }
      ];

      extraOptions = [ ];
    };
  };
}
