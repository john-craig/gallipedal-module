{
  containers = {
    "penpot-frontend" = {
      image = "penpotapp/frontend:latest";
      environment = [
        "PENPOT_FLAGS"
        "PENPOT_HTTP_SERVER_MAX_BODY_SIZE"
        "PENPOT_HTTP_SERVER_MAX_MULTIPART_BODY_SIZE"
      ];
      volumes = [
        {
          containerPath = "/opt/data/assets";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];
      ports = [
        {
          containerPort = "8080";
          protocol = "tcp";
        }
      ];
      proxies = [
        {
          hostname = "penpot.chiliahedron.wtf";
          external = true;
          internal = false;
        }
      ];
    };

    "penpot-backend" = {
      image = "penpotapp/backend:latest";
      environment = [
        "PENPOT_FLAGS"
        "PENPOT_PUBLIC_URI"
        "PENPOT_HTTP_SERVER_MAX_BODY_SIZE"
        "PENPOT_HTTP_SERVER_MAX_MULTIPART_BODY_SIZE"
        "PENPOT_DATABASE_URI"
        "PENPOT_DATABASE_USERNAME"
        "PENPOT_REDIS_URI"
        "PENPOT_ASSETS_STORAGE_BACKEND"
        "PENPOT_STORAGE_ASSETS_FS_DIRECTORY"
        "PENPOT_TELEMETRY_ENABLED"
        "PENPOT_TELEMETRY_REFERER"
        "PENPOT_SMTP_DEFAULT_FROM"
        "PENPOT_SMTP_DEFAULT_REPLY_TO"
        "PENPOT_SMTP_HOST"
        "PENPOT_SMTP_PORT"
        "PENPOT_SMTP_USERNAME"
        "PENPOT_SMTP_TLS"
        "PENPOT_SMTP_SSL"
      ];
      secrets = [
        "PENPOT_DATABASE_PASSWORD"
        "PENPOT_SMTP_PASSWORD"
        "PENPOT_SECRET_KEY"
      ];
      volumes = [
        {
          containerPath = "/opt/data/assets";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];
    };

    "penpot-exporter" = {
      image = "penpotapp/exporter:latest";
      environment = [
        "PENPOT_PUBLIC_URI"
        "PENPOT_REDIS_URI"
      ];
    };

    "penpot-postgres" = {
      image = "postgres:15";
      environment = [
        "POSTGRES_INITDB_ARGS"
        "POSTGRES_DB"
        "POSTGRES_USER"
      ];
      secrets = [
        "POSTGRES_PASSWORD"
      ];
      volumes = [
        {
          containerPath = "/var/lib/postgresql/data";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "999"; # postgres user in container
          volumeGroup = "999";
        }
      ];
    };

    "penpot-valkey" = {
      image = "valkey/valkey:8.1";
    };

    "penpot-mailcatch" = {
      image = "sj26/mailcatcher:latest";
      ports = [
        {
          containerPort = "1080";
          protocol = "tcp";
        }
      ];
    };
  };
}
