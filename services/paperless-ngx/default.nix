{
  containers = {
    "broker" = {
      image = "docker.io/library/redis:7";
      volumes = [
        {
          containerPath = "/data";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
    };
    "webserver" = {
      image = "ghcr.io/paperless-ngx/paperless-ngx:latest";

      environment = [
        "PAPERLESS_REDIS"
        "USERMAP_UID"
        "USERMAP_GID"
        "PAPERLESS_URL"
        "PAPERLESS_SECRET_KEY"
        "PAPERLESS_TIME_ZONE"
        "PAPERLESS_OCR_LANGUAGE"
      ];

      volumes = [
        {
          containerPath = "/usr/src/paperless/data";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/usr/src/paperless/media";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/usr/src/paperless/export";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
        {
          containerPath = "/usr/src/paperless/consume";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];

      ports = [
        {
          containerPort = "8000";
          protocol = "tcp";
        }
      ];

      proxies = [
        {
          hostname = "paperless.chiliahedron.wtf";

          external = true;
          internal = true;
        }
      ];

      dependsOn = [
        "paperless-ngx-broker"
      ];

      extraOptions = [ ];
    };
  };
}
