{ pkgs, lib, config, ... }:
let
  servDefs = import ./services;
  utils = import ./utilities { inherit lib; };
in
{
  options.services.gallipedal = {
    enable = lib.mkEnableOption "Self-hosted Services";

    services = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        options = (lib.attrsets.foldlAttrs
          (acc: servName: servDef:
            acc // {
              "${servName}" = utils.mkServiceOptions servName servDef;
            })
          { }
          servDefs);
      };
    };

    proxyConf = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        options = {
          authenticationMiddleware = lib.mkOption {
            type = lib.types.str;
          };

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

  config =
    let
      enabledServices = lib.filterAttrs (name: value: value.enable != false) config.services.gallipedal.services;

      lowestKey = attrSet:
        let
          # Extract the keys and sort them alphabetically
          sortedKeys = builtins.attrNames attrSet;
        in
        # Return the key corresponding to the alphabetically first key
        builtins.head sortedKeys;

      toProperCase = str:
        let
          lowercaseStr = lib.strings.toLower str;
          replacedStr = builtins.replaceStrings [ "_" ] [ "-" ] lowercaseStr;
        in
        replacedStr;

      authMiddleware = 
        if builtins.hasAttr "authenticationMiddleware" config.services.gallipedal.proxyConf
        then config.services.gallipedal.proxyConf.authenticationMiddleware
        else "";
      internalProxyRules =
        if builtins.hasAttr "internalRules" config.services.gallipedal.proxyConf
        then config.services.gallipedal.proxyConf.internalRules
        else "";
      reverseProxyNetwork =
        if builtins.hasAttr "network" config.services.gallipedal.proxyConf
        then config.services.gallipedal.proxyConf.network
        else "";
      proxyTLSResolver =
        if builtins.hasAttr "tlsResolver" config.services.gallipedal.proxyConf
        then config.services.gallipedal.proxyConf.tlsResolver
        else "";

      # serviceDefinitions = lib.attrsets.getAttrs
      #   enabledServices
      #   servicesLibrary;

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
        reduceServices
          (
            # Lambda function passed to 'reduceServices'
            acc: servName: servDef: (
              # Reduce attribute set of the containers
              # inside this services definition
              lib.attrsets.foldlAttrs
                (
                  # Lambda definition called when reducing
                  # each container definition
                  acc: conName: conDef: (
                    # Actual invocation of caller's lambda function
                    func acc servName servDef conName conDef
                  )
                )
                acc
                servDef.containers
            )
          )
          init
          services
      );

      containerHasLowPort = conDef: (
        lib.attrsets.foldlAttrs
          (acc: conPort: portDef:
            acc || (if (portDef.hostPort != null)
              then ((lib.strings.toInt portDef.hostPort) < 1024)
              else false)
          )
          false
          (lib.attrsets.optionalAttrs
            (builtins.hasAttr "ports" conDef)
            conDef.ports)
      );

      mapVolumeAttrs = servName: conName: conPath: volDef: (
        rec {
          hostPath = volDef.hostPath;

          hostDir =
            if (volDef.volumeType == "directory")
            then hostPath
            else builtins.dirOf hostPath;

          # For a path to a directory, the last subdirectory in the path
          # is used as the container base, (e.g. in /usr/bin/, `bin` would be used)
          # For a path to a file, the the subdirectory containing the file
          # is used as the container base, (e.g. in /usr/bin/test, `bin` would be used)
          hostBase =
            if (volDef.volumeType == "directory")
            then builtins.baseNameOf hostPath
            else builtins.baseNameOf (builtins.dirOf hostPath);
          varHash = builtins.hashString "sha256" "${hostPath}-${conPath}";

          varDir = "/var/lib/selfhosted/${servName}/${conName}/${varHash}-${hostBase}";
          varPath =
            if (volDef.volumeType == "directory")
            then varDir
            else "${varDir}/${builtins.baseNameOf hostPath}";

          faclPerms =
            if (
              (builtins.elemAt (lib.strings.splitString "," volDef.mountOptions) 0) == "rw"
            )
            then "rwx"
            else "rx";

          # Check to see if this is a path we shouldn't try to mess with
          isSystemPath = lib.strings.hasPrefix "/etc" volDef.hostPath;
        }
      );

      mapSecretAttrs = servName: conName: secretName: secretDef: (
        rec {
          secretEnvName = secretName;
          secretPath = secretDef;
          secretProperName = "${servName}-${conName}-${(toProperCase secretEnvName)}";
        }
      );

      mapProxyAttrs = servName: conName: proxyDef: conDef: (
        rec {
          portStr =
            if (builtins.hasAttr "containerPort" proxyDef)
            then proxyDef.containerPort
            else if (builtins.hasAttr "ports" conDef &&
              builtins.length (builtins.attrNames conDef.ports) > 0)
            then lowestKey conDef.ports
            else "";

          urlStr =
            if (builtins.hasAttr "proxyUrl" proxyDef)
            then proxyDef.proxyUrl
            else "";

          hostnameStr =
            if (builtins.hasAttr "hostnames" proxyDef)
            then
              lib.strings.concatStringsSep ", "
                (lib.lists.forEach proxyDef.hostnames (hostname: "`${hostname}`"))
            else "`${proxyDef.hostname}`";

          prefixStr =
            if (builtins.hasAttr "pathPrefix" proxyDef)
            then " && PathPrefix(`${proxyDef.pathPrefix}`)"
            else "";
        }
      );

      mkCommonProxyLabels = proxyType: servName: conName: proxyIdx: proxyIdxStr: proxyDef: conDef: proxyAttrs: (
        {
          "traefik.enable" = "true";
          "traefik.docker.network" = "${reverseProxyNetwork}";
          "traefik.http.routers.${conName}-${proxyIdxStr}-${proxyType}.service" = "${conName}-${proxyIdxStr}-${proxyType}";
          "traefik.http.routers.${conName}-${proxyIdxStr}-${proxyType}.entryPoints" = "websecure";
          "traefik.http.routers.${conName}-${proxyIdxStr}-${proxyType}.rule" = "Host(${proxyAttrs.hostnameStr})${proxyAttrs.prefixStr}";
          "traefik.http.routers.${conName}-${proxyIdxStr}-${proxyType}.tls" = "true";
          "traefik.http.routers.${conName}-${proxyIdxStr}-${proxyType}.tls.certresolver" = "${proxyTLSResolver}";
        } //
        (lib.attrsets.optionalAttrs (proxyAttrs.portStr != "") {
          "traefik.http.services.${conName}-${proxyIdxStr}-${proxyType}.loadbalancer.server.port" = "${proxyAttrs.portStr}";
        }) //
        (lib.attrsets.optionalAttrs (proxyAttrs.urlStr != "") {
          "traefik.http.services.${conName}-${proxyIdxStr}-${proxyType}.loadbalancer.server.url" = "${proxyAttrs.urlStr}";
        })
      );

      mkPublicProxyLabels = servName: conName: proxyIdx: proxyDef: conDef: (
        let
          proxyIdxStr = builtins.toString proxyIdx;
          proxyAttrs = mapProxyAttrs servName conName proxyDef conDef;
        in
        (lib.attrsets.optionalAttrs
          (builtins.hasAttr "public" proxyDef &&
            proxyDef.public)
          (mkCommonProxyLabels "public"
            servName
            conName
            proxyIdx
            proxyIdxStr
            proxyDef
            conDef
            proxyAttrs))
      );

      mkExternalProxyLabels = servName: conName: proxyIdx: proxyDef: conDef: (
        let
          proxyIdxStr = builtins.toString proxyIdx;
          proxyAttrs = mapProxyAttrs servName conName proxyDef conDef;
        in
        (lib.attrsets.optionalAttrs
          (builtins.hasAttr "external" proxyDef &&
            proxyDef.external)
          ((mkCommonProxyLabels "external"
            servName
            conName
            proxyIdx
            proxyIdxStr
            proxyDef
            conDef
            proxyAttrs) // {
          "traefik.http.routers.${conName}-${proxyIdxStr}-external.middlewares" = "${authMiddleware}";
        }))
      );

      mkInternalProxyLabels = servName: conName: proxyIdx: proxyDef: conDef: (
        let
          proxyIdxStr = builtins.toString proxyIdx;
          proxyAttrs = mapProxyAttrs servName conName proxyDef conDef;
        in
        (lib.attrsets.optionalAttrs
          (builtins.hasAttr "internal" proxyDef &&
          proxyDef.internal)
          (mkCommonProxyLabels "internal"
            servName
            conName
            proxyIdx
            proxyIdxStr
            proxyDef
            conDef
            proxyAttrs) // {
          "traefik.http.routers.${conName}-${proxyIdxStr}-internal.rule" = "Host(${proxyAttrs.hostnameStr}) && ${internalProxyRules}${proxyAttrs.prefixStr}";
        })
      );

      reduceProxyDefs = servName: conName: conDef: (
        lib.lists.foldl
          (
            acc: proxyDef: (
              let
                proxyIdx = lib.lists.findFirstIndex (x: x == proxyDef) 0 conDef.proxies;
              in
              acc //
              mkPublicProxyLabels servName conName proxyIdx proxyDef conDef //
              mkInternalProxyLabels servName conName proxyIdx proxyDef conDef //
              mkExternalProxyLabels servName conName proxyIdx proxyDef conDef
            )
          )
          { }
          conDef.proxies
      );

    in
    lib.mkIf config.services.gallipedal.enable {
      environment.systemPackages = [
        pkgs.acl
        pkgs.gnugrep
        # pkgs.bindfs
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

      # Define tmpfiles for each container
      systemd.tmpfiles.rules =
        (reduceContainers (acc: servName: servDef: conName: conDef: (
          acc ++ [
            "d /var/lib/selfhosted/${servName}/${conName} 0770 root root"
          ] ++ lib.lists.optionals (builtins.hasAttr "volumes" conDef) (lib.attrsets.foldlAttrs
            (acc: conPath: volDef:
              let
                volAttrs = mapVolumeAttrs servName conName conPath volDef;
              in
              acc ++ lib.lists.optionals (!volAttrs.isSystemPath) [
                "d ${volAttrs.hostDir} 0770 ${volDef.volumeOwner} ${volDef.volumeGroup}" # Create directory
                "Z ${volAttrs.hostDir} 0770 ${volDef.volumeOwner} ${volDef.volumeGroup}" # Set modes if it doesn't exist
                "A ${volAttrs.hostDir} mask::rwx" # Adjust the mask
              ] ++ lib.lists.optionals (builtins.hasAttr "extraPerms" volDef) (
                (lib.lists.foldl
                  (acc: extraPerms:
                    acc ++ [ "Z ${volDef.hostPath}/${extraPerms.relPath} ${extraPerms.permissions} - - " ])
                  [ ]
                  volDef.extraPerms)
              )
            ) [ ]
            conDef.volumes
          )
        )
        )) [ ]
          enabledServices;

      virtualisation.oci-containers.backend = "podman";

      virtualisation.oci-containers.containers =
        (reduceContainers
          (acc: servName: servDef: conName: conDef: (
            acc // {
              "${servName}-${conName}" = {
                image = conDef.image;

                user = conDef.containerUser;

                cmd = lib.lists.optionals
                  (builtins.hasAttr "cmd" conDef)
                  conDef.cmd;

                entrypoint =
                  if (builtins.hasAttr "entrypoint" conDef)
                  then conDef.entrypoint
                  else null;

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
                  conDef.proxy.external)
                  {
                    "traefik.enable" = "true";
                    "traefik.docker.network" = "${reverseProxyNetwork}";
                    "traefik.http.routers.${conName}-external.entryPoints" = "websecure";
                    "traefik.http.routers.${conName}-external.middlewares" = "${authMiddleware}";
                    "traefik.http.routers.${conName}-external.rule" = "Host(`${conDef.proxy.hostname}`)";
                    "traefik.http.routers.${conName}-external.priority" = 10;
                    "traefik.http.routers.${conName}-external.tls" = "true";
                    "traefik.http.routers.${conName}-external.tls.certresolver" = "${proxyTLSResolver}";
                    "traefik.http.services.${conName}.loadbalancer.server.port" = lowestKey conDef.ports;
                  } //
                lib.attrsets.optionalAttrs
                  (builtins.hasAttr "proxy" conDef &&
                  builtins.hasAttr "hostname" conDef.proxy &&
                  builtins.hasAttr "internal" conDef.proxy &&
                  conDef.proxy.internal)
                  {
                    "traefik.enable" = "true";
                    "traefik.docker.network" = "${reverseProxyNetwork}";
                    "traefik.http.routers.${conName}-internal.entryPoints" = "websecure";
                    "traefik.http.routers.${conName}-internal.rule" = "Host(`${conDef.proxy.hostname}`) && ${internalProxyRules}";
                    "traefik.http.routers.${conName}-internal.priority" = 20;
                    "traefik.http.routers.${conName}-internal.tls" = "true";
                    "traefik.http.routers.${conName}-internal.tls.certresolver" = "${proxyTLSResolver}";
                    "traefik.http.services.${conName}.loadbalancer.server.port" = lowestKey conDef.ports;
                  } //
                lib.attrsets.optionalAttrs
                  (builtins.hasAttr "proxy" conDef &&
                  builtins.hasAttr "hostname" conDef.proxy &&
                  builtins.hasAttr "public" conDef.proxy &&
                  conDef.proxy.public)
                  {
                    "traefik.enable" = "true";
                    "traefik.docker.network" = "${reverseProxyNetwork}";
                    "traefik.http.routers.${conName}-public.entryPoints" = "websecure";
                    "traefik.http.routers.${conName}-public.rule" = "Host(`${conDef.proxy.hostname}`)";
                    "traefik.http.routers.${conName}-public.priority" = 15;
                    "traefik.http.routers.${conName}-public.tls" = "true";
                    "traefik.http.routers.${conName}-public.tls.certresolver" = "${proxyTLSResolver}";
                    "traefik.http.services.${conName}.loadbalancer.server.port" = lowestKey conDef.ports;
                  } //
                lib.attrsets.optionalAttrs
                  (builtins.hasAttr "proxies" conDef)
                  (reduceProxyDefs servName conName conDef) //
                lib.attrsets.optionalAttrs
                  (builtins.hasAttr "extraLabels" conDef)
                  conDef.extraLabels;

                #######################################
                # Environment Variables
                #######################################
                environment = lib.attrsets.optionalAttrs
                  (builtins.hasAttr "environment" conDef)
                  conDef.environment //
                lib.attrsets.optionalAttrs
                  (builtins.hasAttr "environment" servDef)
                  servDef.environment;

                #######################################
                # Ports
                #######################################
                ports = (lib.lists.optionals
                  (builtins.hasAttr "ports" conDef)
                  (lib.attrsets.foldlAttrs
                    (acc: containerPort: portDef:
                      acc ++ lib.lists.optionals (portDef.hostPort != null)
                      [ (if builtins.hasAttr "protocol" portDef
                        then
                          "${portDef.hostPort}:${containerPort}/${portDef.protocol}"
                        else
                          "${portDef.hostPort}:${containerPort}/tcp") ]
                    ) [] conDef.ports));

                #######################################
                # Volumes
                #######################################
                volumes = lib.lists.optionals
                  (builtins.hasAttr "volumes" conDef)
                  (lib.mapAttrsToList
                    (containerPath: volDef:
                      let
                        volAttrs = mapVolumeAttrs servName conName containerPath volDef;
                      in
                      if builtins.hasAttr "mountOptions" volDef
                      then
                        "${volAttrs.varPath}:${containerPath}:${volDef.mountOptions}"
                      else
                        "${volAttrs.varPath}:${containerPath}"
                    )
                    conDef.volumes);

                #######################################
                # Miscellaneous
                #######################################
                log-driver = "journald";

                extraOptions =
                  # Add any extra options
                  lib.lists.optionals (builtins.hasAttr "extraOptions" conDef)
                    conDef.extraOptions ++

                  # Add any secrets
                  lib.lists.optionals (builtins.hasAttr "secrets" conDef)
                    (lib.attrsets.mapAttrsToList
                      (secretName: secretDef:
                        let
                          secretAttrs = mapSecretAttrs servName conName secretName secretDef;
                        in
                        "--secret=${secretAttrs.secretProperName},type=env,target=${secretAttrs.secretEnvName}"
                      )
                      conDef.secrets) ++

                  # Connect to proxy network
                  lib.lists.optionals
                    (builtins.hasAttr "proxy" conDef ||
                    builtins.hasAttr "proxies" conDef)
                    [ "--network=${reverseProxyNetwork}" ] ++

                  # Connect to external network
                  lib.lists.optionals
                    (builtins.hasAttr "networks" conDef &&
                    builtins.hasAttr "external" conDef.networks &&
                    conDef.networks.external)
                    [ "--network=${servName}-external" ] ++

                  # Add default network connections
                  [
                    "--network-alias=${conName}"
                    "--network=${servName}-internal"
                  ];

                dependsOn = lib.mkIf (builtins.hasAttr "dependsOn" conDef) conDef.dependsOn;
              };
            }
          )
          )
          { }
          enabledServices);

      # Define users for each container within each service
      users.groups = {
        "selfhosting" = { };
        "containers" = { };
      };

      users.users = {
        "selfhosting" = {
          isSystemUser = true;
          group = "selfhosting";
        };
      };

      systemd.services =
        # Define mounts for each container
        (
          (reduceContainers (acc: servName: servDef: conName: conDef: (
            acc // lib.attrsets.optionalAttrs
              (builtins.hasAttr "volumes" conDef)
              {
                "podman-mount-${servName}-${conName}" = {
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                  };
                  path = [ pkgs.bindfs ];
                  script = lib.strings.concatLines (lib.attrsets.mapAttrsToList
                    (containerPath: volDef:
                      let
                        volAttrs = mapVolumeAttrs servName conName containerPath volDef;
                      in
                      ''
                        ${pkgs.umount}/bin/umount ${volAttrs.varDir} || true
                        rm -rf ${volAttrs.varDir} || true
                        mkdir ${volAttrs.varDir}
                        ${pkgs.util-linux}/bin/mount --bind ${volAttrs.hostDir} ${volAttrs.varDir}
                      ''
                    )
                    conDef.volumes);
                  postStop = lib.strings.concatLines (lib.attrsets.mapAttrsToList
                    (containerPath: volDef:
                      let
                        volAttrs = mapVolumeAttrs servName conName containerPath volDef;
                      in
                      ''
                        ${pkgs.umount}/bin/umount ${volAttrs.varDir} || true
                        rm -rf ${volAttrs.varDir} || true
                      ''
                    )
                    conDef.volumes);
                  after = [
                    "podman-network-${servName}.service"
                    "systemd-tmpfiles-setup.service"
                  ];
                  requires = [
                    "podman-network-${servName}.service"
                    "systemd-tmpfiles-setup.service"
                  ];
                  partOf = [
                    "podman-compose-${servName}-root.target"
                  ];
                  wantedBy = [
                    "podman-compose-${servName}-root.target"
                  ];
                };
              }
          )
          ))
            { }
            enabledServices) //
        # Define secrets for each container
        (
          (reduceContainers (acc: servName: servDef: conName: conDef: (
            acc // lib.attrsets.optionalAttrs
              (builtins.hasAttr "secrets" conDef)
              {
                "podman-secrets-${servName}-${conName}" = {
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                  };
                  path = [ pkgs.podman ];
                  script = lib.strings.concatLines (lib.attrsets.mapAttrsToList
                    (secretName: secretDef:
                      let
                        secretAttrs = mapSecretAttrs servName conName secretName secretDef;
                      in
                      ''
                        podman secret create ${secretAttrs.secretProperName} ${secretAttrs.secretPath}
                      ''
                    )
                    conDef.secrets);
                  postStop = lib.strings.concatLines (lib.attrsets.mapAttrsToList
                    (secretName: secretDef:
                      let
                        secretAttrs = mapSecretAttrs servName conName secretName secretDef;
                      in
                      ''
                        podman secret rm ${secretAttrs.secretProperName}
                      ''
                    )
                    conDef.secrets);
                  after = [
                    "podman-network-${servName}.service"
                  ];
                  requires = [
                    "podman-network-${servName}.service"
                  ];
                  partOf = [
                    "podman-compose-${servName}-root.target"
                  ];
                  wantedBy = [
                    "podman-compose-${servName}-root.target"
                  ];
                };
              }
          )
          ))
            { }
            enabledServices) //
        # Define services for each container
        (
          (reduceContainers (acc: servName: servDef: conName: conDef: (
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
                  (builtins.length (lib.attrsets.attrValues conDef.volumes)) > 0)
                  [ "podman-mount-${servName}-${conName}.service" ]
                ++ lib.lists.optionals
                  (builtins.hasAttr "secrets" conDef)
                  [ "podman-secrets-${servName}-${conName}.service" ];
                requires = [
                  "podman-network-${servName}.service"
                ] ++ lib.lists.optionals
                  (builtins.hasAttr "volumes" conDef &&
                  (builtins.length (lib.attrsets.attrValues conDef.volumes)) > 0)
                  [ "podman-mount-${servName}-${conName}.service" ]
                ++ lib.lists.optionals
                  (builtins.hasAttr "secrets" conDef)
                  [ "podman-secrets-${servName}-${conName}.service" ];
                partOf = [
                  "podman-compose-${servName}-root.target"
                ];
                wantedBy = [
                  "podman-compose-${servName}-root.target"
                ];
              };
            }
          )
          ))
            { }
            enabledServices) //
        # Define internal networks for each service
        (reduceServices
          (acc: servName: servDef: (
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
            }
          )
          )
          { }
          enabledServices) //
        # Define global external networks
        (reduceContainers
          (acc: servName: servDef: conName: conDef: (
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
              }
          )
          )
          { }
          enabledServices);

      # Define a target for each service
      systemd.targets =
        builtins.listToAttrs (lib.attrsets.mapAttrsToList
          (servName: servDef: {
            "name" = "podman-compose-${servName}-root";
            "value" = {
              unitConfig = {
                Description = "Root target for ${servName} service";
              };
              wantedBy = [ "multi-user.target" ];
            };
          })
          enabledServices);
    };
}
