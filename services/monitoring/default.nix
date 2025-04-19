{
  containers = {
    "grafana" = {
      image = "grafana/grafana-oss:11.5.0";

      volumes = [
        {
          containerPath = "/var/lib/grafana";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "3000";
          protocol = "tcp";
        }
      ];
      proxies = [
        {
          hostname = "grafana.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };

    "prometheus" = {
      image = "prom/prometheus:v2.30.3";
      volumes = [
        {
          containerPath = "/etc/prometheus";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/prometheus";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "9090";
          protocol = "tcp";
        }
      ];
      proxies = [
        {
          hostname = "prometheus.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [ ];
    };

    "influxdb" = {
      image = "influxdb:latest";
      volumes = [
        {
          containerPath = "/etc/influxdb2";
          mountOptions = "rw";
          volumeType = "directory";
        }
        {
          containerPath = "/var/lib/influxdb2";
          mountOptions = "rw";
          volumeType = "directory";
        }
      ];
      ports = [
        {
          containerPort = "8086";
          protocol = "tcp";
        }
      ];
      proxies = [
        {
          hostname = "influxdb.chiliahedron.wtf";

          external = false; # Temporarily disabled
          internal = true;
        }
      ];

      extraOptions = [

      ];
    };

  };
}
