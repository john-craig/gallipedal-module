{
  containers = {
    "authelia" = {
      image = "docker.io/authelia/authelia:latest";
      environment = [ "TZ" ];
        
      volumes = [
        {
          containerPath = "/config";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "9091";
          protocol = "tcp";
        }
      ];

      # Labels for Traefik to use as a Proxy
      extraLabels = {
        "traefik.http.middlewares.authelia-basic.forwardAuth.address" = "http://authelia:9091/api/verify?auth=basic";
        "traefik.http.middlewares.authelia-basic.forwardAuth.authResponseHeaders" = "Remote-User,Remote-Groups,Remote-Name,Remote-Email";
        "traefik.http.middlewares.authelia-basic.forwardAuth.trustForwardHeader" = "true";
        "traefik.http.middlewares.authelia.forwardAuth.address" = "http://authelia:9091/api/verify?rd=https%3A%2F%2Fauthelia.chiliahedron.wtf%2F";
        "traefik.http.middlewares.authelia.forwardAuth.authResponseHeaders" = "Remote-User,Remote-Groups,Remote-Name,Remote-Email";
        "traefik.http.middlewares.authelia.forwardAuth.trustForwardHeader" = "true";
      };
    };
  };
}
