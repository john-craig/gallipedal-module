{
  containers = {
    "base" = {
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
      ];

      cmd = [ "--user-profiles" "/profiles" "--profile" "en" ];
      
      proxies = [
        {
          hostname = "rhasspy.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };

  };
}
