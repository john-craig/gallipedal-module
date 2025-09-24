{
  containers = {
    # "drone-agent" = {
    #   image = "drone/drone-runner-docker:1";
    #   environment = {
    #     DRONE_RPC_HOST = "drone.chiliahedron.wtf";
    #     DRONE_RPC_PROTO = "https";
    #     DRONE_RPC_SECRET = "9c3921e3e748aff725d2e16ef31fbc42";
    #     DRONE_RUNNER_CAPACITY = "2";
    #     DRONE_RUNNER_NAME = "drone-docker-runner";
    #   };
    #   volumes = [
    #     {
    #       hostPath = "/var/run/podman.sock";
    #       containerPath = "/var/run/docker.sock";
    #       mountOptions = "rw";
    #     }
    #   ];
    #   cmd = [ "agent" ];
    #   proxies = [
    # {

    #       hostname = "drone.chiliahedron.wtf";

    #       external = false; # Temporarily disabled
    #       internal = true;
    #         
    #   }
    # ];

    #   extraOptions = [
    #     "--network-alias=gitea"
    #     "--network=chiliahedron-services"
    #     "--network=gitea"
    #   ];
    # };

    "gitea" = {
      image = "gitea/gitea:latest-rootless";

      environment = [
        "USER_GID"
        "USER_UID"
        "GITEA_APP_INI"
        "GITEA_TMP"
        "GITEA_CUSTOM"
        "GITEA_WORK_DIR"
      ];

      volumes = [
        {
          containerPath = "/etc/localtime";
          mountOptions = "ro";
          volumeType = "file";
        }
        {
          containerPath = "/etc/timezone";
          mountOptions = "ro";
          volumeType = "directory";
        }
        {
          containerPath = "/data";
          mountOptions = "rw";
          volumeType = "directory";
          volumeOwner = "1000";
          volumeGroup = "1000";
        }

      ];

      ports = [
        {
          containerPort = "3000";
          protocol = "tcp";
        }
        {
          containerPort = "2222";
          protocol = "tcp";
        }
      ];
    };

  };
}
