 { gallipedal-library, ... }: 
 { pkgs, lib, config, ... }: 
let  
  # shLib = import ./lib/default.nix;
  servicesLibrary = gallipedal-library.default;
in {
  options.services.gallipedal = {
    enable = lib.mkEnableOption "Self-hosted Services";

    services = lib.mkOption {
      type = lib.types.listOf lib.types.str;
    };

    proxyConf = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        options = {
          internalRules = lib.mkOption {
            type = lib.types.str;
          };

          network = lib.mkOption {
            type = lib.types.str;
          };

          tlsResolver = lib.mkOption {
            type = lib.types.str;
          };
        };
      };
    };
  };

    # services = mkOption {
    #   default = { };
    #   example = { };
    #   description = lib.mdDoc ''
    #     A definition for the selfhosted service.
    #   '';

    #   type = with types; attrsOf (submodules (
    #     { config, name, ... }: { options = {
    #       enable = mkEnableOption "Self-hosted service defined by this option";

    #       name = mkOption {
    #         visible = false;
    #         default = name;
    #         example = "nginx";
    #         type = types.str;
    #         description = lib.mdDoc "Name of the service to be run.";
    #       };
    #     }}
    #   ));
    # };

  config = let
    internalProxyRules = if builtins.hasAttr "internalRules" config.services.gallipedal.proxyConf
      then config.services.gallipedal.proxyConf.internalRules
      else "";
    reverseProxyNetwork = if builtins.hasAttr "network" config.services.gallipedal.proxyConf
      then config.services.gallipedal.proxyConf.network
      else "";
    proxyTLSResolver = if builtins.hasAttr "tlsResolver" config.services.gallipedal.proxyConf
      then config.services.gallipedal.proxyConf.tlsResolver
      else "";

    serviceDefinitions = lib.attrsets.getAttrs
        config.services.gallipedal.services
        servicesLibrary;

      # Invoke the function 'func' with
      #   acc: servName: servDef
      # for each service in services
      reduceServices = func: init: services: (
        lib.attrsets.foldlAttrs func init services
      );

      # Invoke the function 'func' with
      #   acc: servName: servDef: conName: conDef
      # for each container in each service
      reduceContainers = func: init: services: (
        reduceServices (
          # Lambda function passed to 'reduceServices'
          acc: servName: servDef: (
            # Reduce attribute set of the containers
            # inside this services definition
            lib.attrsets.foldlAttrs (
              # Lambda definition called when reducing
              # each container definition
              acc: conName: conDef: (
                # Actual invocation of caller's lambda function
                func acc servName servDef conName conDef
              )
            ) acc servDef.containers
          )) init services
        );
      
      containerHasLowPort = conDef: (
        lib.lists.foldl (acc: portDef:
          acc || (lib.strings.toInt portDef.hostPort) < 1024
        ) false (lib.lists.optionals 
              (builtins.hasAttr "ports" conDef)
              conDef.ports)
      );

      mapVolumeAttrs = servName: conName: volDef: (
        rec {
          conPath = volDef.containerPath;
          hostPath = volDef.hostPath;

          hostDir = if lib.filesystem.pathIsDirectory (/. + hostPath)
            then hostPath
            else builtins.dirOf hostPath;

          # For a path to a directory, the last subdirectory in the path
          # is used as the container base, (e.g. in /usr/bin/, `bin` would be used)
          # For a path to a file, the the subdirectory containing the file
          # is used as the container base, (e.g. in /usr/bin/test, `bin` would be used)
          hostBase = if lib.filesystem.pathIsDirectory (/. + hostPath)
            then builtins.baseNameOf hostPath
            else builtins.baseNameOf (builtins.dirOf hostPath);
          varHash = builtins.hashString "sha256" "${hostPath}-${conPath}";

          varDir = "/var/lib/selfhosted/${servName}/${conName}/${varHash}-${hostBase}";
          varPath = if lib.filesystem.pathIsDirectory (/. + hostPath)
            then varDir
            else "${varDir}/${builtins.baseNameOf hostPath}";
        }
      );

      mapProxyAttrs = servName: conName: proxyDef: conDef: (
        rec {
          portStr = if (builtins.hasAttr "containerPort" proxyDef)
            then proxyDef.containerPort
            else (builtins.elemAt conDef.ports 0).containerPort;
          hostnameStr = if (builtins.hasAttr "hostnames" proxyDef)
            then lib.strings.concatStringsSep ", "
              lib.lists.forEach proxyDef.hostnames (hostname: "`${hostname}`")
            else "`${proxyDef.hostname}`";
        }
      );

      mkPublicProxyLabels = servName: conName: proxyDef: conDef: (
        let
          proxyAttrs = mapProxyAttrs servName conName proxyDef conDef;
        in 
        (lib.attrsets.optionalAttrs 
          (builtins.hasAttr "public" proxyDef &&
           proxyDef.public) 
        {
          "traefik.enable" = "true";
          "traefik.docker.network" = "${reverseProxyNetwork}";
          "traefik.http.services.${conName}-public.loadbalancer.server.port" = "${proxyAttrs.portStr}";
          "traefik.http.routers.${conName}-public.service" = "${conName}-public";
          "traefik.http.routers.${conName}-public.entryPoints" = "websecure";
          "traefik.http.routers.${conName}-public.rule" = "Host(${proxyAttrs.hostnameStr})";
          "traefik.http.routers.${conName}-public.tls" = "true";
          "traefik.http.routers.${conName}-public.tls.certresolver" = "${proxyTLSResolver}";
        })
      );

      mkExternalProxyLabels = servName: conName: proxyDef: conDef: (
        let
          proxyAttrs = mapProxyAttrs servName conName proxyDef conDef;
        in 
        (lib.attrsets.optionalAttrs 
          (builtins.hasAttr "external" proxyDef &&
           proxyDef.external) 
        {
          "traefik.enable" = "true";
          "traefik.docker.network" = "${reverseProxyNetwork}";
          "traefik.http.services.${conName}-external.loadbalancer.server.port" = "${proxyAttrs.portStr}";
          "traefik.http.routers.${conName}-external.service" = "${conName}-external";
          "traefik.http.routers.${conName}-external.entryPoints" = "websecure";
          "traefik.http.routers.${conName}-external.middlewares" = "authelia@docker";
          "traefik.http.routers.${conName}-external.rule" = "Host(${proxyAttrs.hostnameStr})";
          "traefik.http.routers.${conName}-external.tls" = "true";
          "traefik.http.routers.${conName}-external.tls.certresolver" = "${proxyTLSResolver}";
        })
      );

      mkInternalProxyLabels = servName: conName: proxyDef: conDef: (
        let
          proxyAttrs = mapProxyAttrs servName conName proxyDef conDef;
        in 
        (lib.attrsets.optionalAttrs 
          (builtins.hasAttr "internal" proxyDef &&
           proxyDef.internal) 
        {
          "traefik.enable" = "true";
          "traefik.docker.network" = "${reverseProxyNetwork}";
          "traefik.http.services.${conName}-internal.loadbalancer.server.port" = "${proxyAttrs.portStr}";
          "traefik.http.routers.${conName}-internal.service" = "${conName}-internal";
          "traefik.http.routers.${conName}-internal.entryPoints" = "websecure";
          "traefik.http.routers.${conName}-internal.rule" = "Host(${proxyAttrs.hostnameStr}) && ${internalProxyRules}";
          "traefik.http.routers.${conName}-internal.tls" = "true";
          "traefik.http.routers.${conName}-internal.tls.certresolver" = "${proxyTLSResolver}";
        })
      );

      reduceProxyDefs = servName: conName: conDef: (
        lib.lists.foldl (
          acc: proxyDef: (
            acc // 
              mkPublicProxyLabels servName conName proxyDef conDef //
              mkInternalProxyLabels servName conName proxyDef conDef //
              mkExternalProxyLabels servName conName proxyDef conDef
          )
        ) {} conDef.proxies
      );

    in lib.mkIf config.services.gallipedal.enable {
    environment.systemPackages = [
      pkgs.acl
      pkgs.gnugrep
      pkgs.bindfs
    ];

    virtualisation.podman = {
      enable = true;
      autoPrune.enable = true;
      dockerCompat = true;
      defaultNetwork.settings = {
        # Required for container networking to be able to use names.
        dns_enabled = true;
      };
    };

    virtualisation.oci-containers.backend = "podman";

    virtualisation.oci-containers.containers =
      (reduceContainers (acc: servName: servDef: conName: conDef: (
        acc // {
          "${servName}-${conName}" = {
            image = conDef.image;

            cmd = lib.lists.optionals
              (builtins.hasAttr "cmd" conDef) conDef.cmd;

            #######################################
            # Labels
            #######################################
            labels = {
              "wtf.chiliahedron.project-name" = servName;
            } // 
            lib.attrsets.optionalAttrs 
              (builtins.hasAttr "proxy" conDef &&
                builtins.hasAttr "hostname" conDef.proxy &&
                builtins.hasAttr "external" conDef.proxy &&
                conDef.proxy.external) {
                "traefik.enable" = "true";
                "traefik.docker.network" = "${reverseProxyNetwork}";
                "traefik.http.routers.${conName}-external.entryPoints" = "websecure";
                "traefik.http.routers.${conName}-external.middlewares" = "authelia@docker";
                "traefik.http.routers.${conName}-external.rule" = "Host(`${conDef.proxy.hostname}`)";
                "traefik.http.routers.${conName}-external.tls" = "true";
                "traefik.http.routers.${conName}-external.tls.certresolver" = "${proxyTLSResolver}";
                "traefik.http.services.${conName}.loadbalancer.server.port" = (builtins.elemAt conDef.ports 0).containerPort;
              } //
            lib.attrsets.optionalAttrs 
              (builtins.hasAttr "proxy" conDef &&
              builtins.hasAttr "hostname" conDef.proxy &&
              builtins.hasAttr "internal" conDef.proxy &&
              conDef.proxy.internal) {
                "traefik.enable" = "true";
                "traefik.docker.network" = "${reverseProxyNetwork}";
                "traefik.http.routers.${conName}-internal.entryPoints" = "websecure";
                "traefik.http.routers.${conName}-internal.rule" = "Host(`${conDef.proxy.hostname}`) && ${internalProxyRules}";
                "traefik.http.routers.${conName}-internal.tls" = "true";
                "traefik.http.routers.${conName}-internal.tls.certresolver" = "${proxyTLSResolver}";
                "traefik.http.services.${conName}.loadbalancer.server.port" = (builtins.elemAt conDef.ports 0).containerPort;
              } //
            lib.attrsets.optionalAttrs 
              (builtins.hasAttr "proxy" conDef &&
              builtins.hasAttr "hostname" conDef.proxy &&
              builtins.hasAttr "public" conDef.proxy &&
              conDef.proxy.public) {
                "traefik.enable" = "true";
                "traefik.docker.network" = "${reverseProxyNetwork}";
                "traefik.http.routers.${conName}-public.entryPoints" = "websecure";
                "traefik.http.routers.${conName}-public.rule" = "Host(`${conDef.proxy.hostname}`)";
                "traefik.http.routers.${conName}-public.tls" = "true";
                "traefik.http.routers.${conName}-public.tls.certresolver" = "${proxyTLSResolver}";
                "traefik.http.services.${conName}.loadbalancer.server.port" = (builtins.elemAt conDef.ports 0).containerPort;
              } //
            lib.attrsets.optionalAttrs 
              (builtins.hasAttr "proxies" conDef) 
              (reduceProxyDefs servName conName conDef) //
            lib.attrsets.optionalAttrs
              (builtins.hasAttr "extraLabels" conDef) conDef.extraLabels;

            #######################################
            # Environment Variables
            #######################################
            environment = lib.attrsets.optionalAttrs 
              (builtins.hasAttr "environment" conDef) conDef.environment;

            #######################################
            # Ports
            #######################################
            ports = lib.lists.optionals 
              (builtins.hasAttr "ports" conDef)
              (builtins.map (port: 
                if builtins.hasAttr "protocol" port
                then
                  "${port.hostPort}:${port.containerPort}/${port.protocol}"
                else
                  "${port.hostPort}:${port.containerPort}/tcp"
              ) conDef.ports);
          
            #######################################
            # Volumes
            #######################################
            volumes = lib.lists.optionals 
              (builtins.hasAttr "volumes" conDef)
              (builtins.map (volDef: 
                let
                  volAttrs = mapVolumeAttrs servName conName volDef;
                in
                  if builtins.hasAttr "mountOptions" volDef
                  then
                    "${volAttrs.varPath}:${volDef.containerPath}:${volDef.mountOptions},U"
                  else
                    "${volAttrs.varPath}:${volDef.containerPath}:U"
              ) conDef.volumes);

            #######################################
            # Miscellaneous
            #######################################
            log-driver = "journald";

            extraOptions = 
              # Add any extra options
              lib.lists.optionals (builtins.hasAttr "extraOptions" conDef)
                conDef.extraOptions ++

              # Connect to proxy network
              lib.lists.optionals (builtins.hasAttr "proxy" conDef ||
                                   builtins.hasAttr "proxies" conDef)
                [ "--network=${reverseProxyNetwork}" ] ++

              # Connect to external network
              lib.lists.optionals (builtins.hasAttr "networks" conDef &&
                builtins.hasAttr "external" conDef.networks &&
                conDef.networks.external)
                [ "--network=${servName}-external" ] ++

              # Add default network connections
              [ "--network-alias=${conName}"
                "--network=${servName}-internal" 
              ];

            dependsOn = lib.mkIf (builtins.hasAttr "dependsOn" conDef) conDef.dependsOn;
          };
        })
      ) {} serviceDefinitions);
  
    # Define users for each container within each service
    users.groups = (reduceContainers (acc: servName: servDef: conName: conDef: (
        acc // {
          "${servName}-${conName}" = {};
        })
      )) {} serviceDefinitions;

    users.users = (reduceContainers (acc: servName: servDef: conName: conDef: (
        acc // {
          "${servName}-${conName}" = { 
            isSystemUser = true;
            group = "${servName}-${conName}";
          };
        })
      )) {} serviceDefinitions;

    # Define tmpfiles for each container
    systemd.tmpfiles.rules = (reduceContainers (acc: servName: servDef: conName: conDef: (
      acc ++ [
        (let 
          user = "${servName}-${conName}"; 
          group = "${servName}-${conName}";
        in 
          "d /var/lib/selfhosted/${servName}/${conName} 0700 ${user} ${group}")
      ]
     )
    )) [] serviceDefinitions;
    

    systemd.services = 
      # Define mounts for each container
      ((reduceContainers (acc: servName: servDef: conName: conDef: (
        acc // lib.attrsets.optionalAttrs 
        (builtins.hasAttr "volumes" conDef) {
          "podman-mount-${servName}-${conName}" = {
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            path = [ pkgs.bindfs ];
            script = lib.strings.concatLines (builtins.map (volDef:
              let
                volAttrs = mapVolumeAttrs servName conName volDef;
              in
                ''
                  ${pkgs.umount}/bin/umount ${volAttrs.varDir} || true
                  rm -rf ${volAttrs.varDir} || true
                  mkdir ${volAttrs.varDir}
                  ${pkgs.util-linux}/bin/mount --bind ${volAttrs.hostDir} ${volAttrs.varDir}
                ''
            ) conDef.volumes);
            postStop = lib.strings.concatLines (builtins.map (volDef:
              let
                volAttrs = mapVolumeAttrs servName conName volDef;
              in
                ''
                  ${pkgs.umount}/bin/umount ${volAttrs.varDir} || true
                  rm -rf ${volAttrs.varDir} || true
                ''
            ) conDef.volumes);
            after = [
              "podman-network-${servName}.service"
              # TODO: make dependent on corresponding tmpfiles rule
              # "podman-mount-${servName}-${conName}.service"
            ];
            requires = [
              "podman-network-${servName}.service"
              # TODO: make dependent on corresponding tmpfiles rule
              # "podman-mount-${servName}-${conName}.service"
            ];
            partOf = [
              "podman-compose-${servName}-root.target"
            ];
            wantedBy = [
              "podman-compose-${servName}-root.target"
            ];
          };
        })
      )) {} serviceDefinitions) //
      # Define services for each container
      ((reduceContainers (acc: servName: servDef: conName: conDef: (
        acc // {
          "podman-${servName}-${conName}" = {
            serviceConfig = {
              Restart = lib.mkOverride 500 "always";
            } //
            # If the container is the reverse proxy for the
            # cluster, it gets some sepcial capabilities
              lib.attrsets.optionalAttrs 
               (containerHasLowPort conDef)
               {
                  # AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
                  # CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
               };
            after = [
              "podman-network-${servName}.service"
            ] ++ lib.lists.optionals
              (builtins.hasAttr "volumes" conDef &&
               (builtins.length conDef.volumes) > 0)
              [ "podman-mount-${servName}-${conName}.service" ];
            requires = [
              "podman-network-${servName}.service"
            ] ++ lib.lists.optionals
              (builtins.hasAttr "volumes" conDef &&
               (builtins.length conDef.volumes) > 0)
              [ "podman-mount-${servName}-${conName}.service" ];
            partOf = [
              "podman-compose-${servName}-root.target"
            ];
            wantedBy = [
              "podman-compose-${servName}-root.target"
            ];
          };
        })
      )) {} serviceDefinitions) //
      # Define internal networks for each service
      (reduceServices (acc: servName: servDef: (
        acc // {
          "podman-network-${servName}" = {
            path = [ pkgs.podman ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              podman network inspect ${servName}-internal || podman network create ${servName}-internal --internal
              podman network inspect ${servName}-external || podman network create ${servName}-external
            '';
            postStop = ''
              ${pkgs.podman}/bin/podman network rm -f ${servName}-internal
              ${pkgs.podman}/bin/podman network rm -f ${servName}-external
            '';
            partOf = [ "podman-compose-${servName}-root.target" ];
            wantedBy = [ "podman-compose-${servName}-root.target" ];
          };
        })
      ) {} serviceDefinitions) //
      # Define global external networks
      (reduceContainers (acc: servName: servDef: conName: conDef: (
        acc //
        # Reverse proxy network
        lib.attrsets.optionalAttrs 
          (builtins.hasAttr "proxy" conDef ||
           builtins.hasAttr "proxies" conDef)
          {
            "podman-network-${reverseProxyNetwork}" = {
              path = [ pkgs.podman ];
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
              script = ''
                podman network inspect ${reverseProxyNetwork} || podman network create ${reverseProxyNetwork}
              '';
              postStop = ''
                ${pkgs.podman}/bin/podman network rm -f ${reverseProxyNetwork}
              '';
              partOf = [ "podman-compose-${servName}-root.target" ];
              wantedBy = [ "podman-compose-${servName}-root.target" ];
            };
          })
      ) {} serviceDefinitions);
    
    # Define a target for each service
    systemd.targets = 
      builtins.listToAttrs (builtins.map (servName: {
        "name" = "podman-compose-${servName}-root";
        "value" = {
          unitConfig = {
            Description = "Root target for ${servName} service";
          };
          wantedBy = [ "multi-user.target" ];
        };
      }) config.services.gallipedal.services);
  };
}