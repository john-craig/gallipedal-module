{
  containers = {
    "archivebox" = {
      image = "archivebox/archivebox:latest";
      environment = [
        "ADMIN_USERNAME"
        "ALLOWED_HOSTS"
        "PUBLIC_ADD_VIEW"
        "PUBLIC_INDEX"
        "PUBLIC_SNAPSHOTS"
        "SAVE_ARCHIVE_DOT_ORG"
        "SEARCH_BACKEND_ENGINE"
        "SEARCH_BACKEND_HOST_NAME"
        "PUID"
        "PGID"
      ];

      secrets = [
        "ADMIN_PASSWORD"
        "SEARCH_BACKEND_PASSWORD"
      ];

      volumes = [
        {
          containerPath = "/data";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";

          # extraPerms = [
          #   {
          #     relPath = ".";
          #     permissions = "777";
          #   }
          # ];
        }
      ];
      ports = [
        {
          containerPort = "8000";
          protocol = "tcp";
        }
      ];

      extraOptions = [ ];

      cmd = [ "server" "--quick-init" "0.0.0.0:8000" ];
      # cmd = ["init"];
    };

    "sonic" = {
      image = "valeriansaliou/sonic:latest";
      secrets = [
        "SEARCH_BACKEND_PASSWORD"
      ];

      volumes = [
        {
          containerPath = "/var/lib/sonic/store";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/etc/sonic.cfg";
          mountOptions = "ro";
          volumeType = "file";
        }
      ];

      extraOptions = [ ];
    };
  };
}
