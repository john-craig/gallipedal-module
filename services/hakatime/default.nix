{
  containers = {
    "hakatime" = {
      image = "mujx/hakatime:v1.6.1";
      environment = [
        "HAKA_DB_HOST"
        "HAKA_DB_PORT"
        "HAKA_DB_NAME"
        "HAKA_DB_USER"

        "HAKA_BADGE_URL"
        "HAKA_PORT"
        "HAKA_SHIELD_IO_URL"
        "HAKA_ENABLE_REGISTRATION"

        "HAKA_SESSION_EXPIRY"
        "HAKA_LOG_LEVEL"
        "HAKA_ENV"
      ];

      secrets = [
        "HAKA_DB_PASS"
      ];

      ports = [
        {
          containerPort = "8080";
          protocol = "tcp";
        }
      ];

      extraOptions = [ ];
    };

    "haka_db" = {
      image = "postgres:12-alpine";
      environment = [
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
          volumeOwner = "1000";
          volumeGroup = "1000";
        }
      ];
    };
  };
}
