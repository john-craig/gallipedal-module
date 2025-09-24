{
  containers = {
    "n8n" = {
      image = "docker.n8n.io/n8nio/n8n";
      environment = [
        "N8N_HOST"
        "N8N_PORT"
        "N8N_PROTOCOL"
        "NODE_ENV"
        "WEBHOOK_URL"
        "GENERIC_TIMEZONE"
      ];
      volumes = [
        {
          containerPath = "/home/node/.n8n";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "5678";
          protocol = "tcp";
        }
      ];

      dependsOn = [ ];

      extraOptions = [

      ];
    };
  };
}
