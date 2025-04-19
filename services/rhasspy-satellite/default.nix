{
  containers = {
    "satellite" = {
      image = "rhasspy/rhasspy";
      volumes = [
        {
          containerPath = "/etc/localtime";
          mountOptions = "ro";
          volumeType = "file";
        }
        {
          containerPath = "/profiles";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "12101";
          protocol = "tcp";
        }
        {
          containerPort = "12183";
          protocol = "tcp";
        }
        {
          containerPort = "12333";
          protocol = "udp";
        }
      ];

      cmd = [ "--user-profiles" "/profiles" "--profile" "en" ];
      
      networks = {
        external = false; # Temporarily disabled
      };

      extraOptions = [ "--device=/dev/snd:/dev/snd" ];
    };

  };
}
