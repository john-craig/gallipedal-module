{ pkgs, lib, config, ... }:
let
  servDefs = import ./services;
  utils = import ./utilities { inherit lib; };

  ################################################################
  # Constants / allocation helpers for rootless users and ranges
  ################################################################
  uidBase = 32768;                        # first uid/gid for our system users
  uidMax  = 65535;
  subRangeSize = 1024;                    # number of subuids/subgids allocated per user
  maxUsers = (uidMax - uidBase) + 1;

  # deterministic UID for a given name (index must be small enough)
  mkUidFromIndex = idx: (uidBase + idx);

  # given index, create "start:size" string for subuid/subgid file
  mkSubRange = idx: "${toString (uidBase + idx * subRangeSize)}:${toString subRangeSize}";

  ################################################################
  # Existing helpers (unchanged)
  ################################################################
  utilsAll = utils;
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
          sortedKeys = builtins.attrNames attrSet;
        in
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

      #############################################################################
      # Reduced traversal helpers (unchanged)
      #############################################################################
      reduceServices = func: init: services: (
        lib.attrsets.foldlAttrs func init services
      );

      reduceContainers = func: init: services: (
        reduceServices
          (
            acc: servName: servDef:
              lib.attrsets.foldlAttrs
                (
                  acc: conName: conDef:
                    func acc servName servDef conName conDef
                )
                acc
                servDef.containers
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

      #############################################################################
      # New rootless helpers
      #############################################################################
      # Build a flat list of all enabled containers (servName/conName) for deterministic indexing
      enabledContainersList =
        lib.attrsets.foldlAttrs
          (acc: servName: servDef:
            acc ++ (lib.attrsets.attrNames (lib.attrsets.optionalAttrs true servDef.containers))
          )
          [ ]
          enabledServices;

      # helper: find index of a container in the flat list (used for UID assignment)
      containerIndex = servName: conName:
        let full = "${servName}-${conName}";
        idx = lib.lists.findFirstIndex (x: x == full) 0 enabledContainersList;
        in idx;

      # per-container system user name
      containerSystemUser = servName: conName: "ctr-${servName}-${conName}";

      # per-container runtime/home and persistent storage dirs
      containerRuntimeDir = servName: conName: "/var/run/${containerSystemUser servName conName}";
      containerPersistDir = servName: conName: "/var/lib/containers/${containerSystemUser servName conName}";

      # minimal templates for per-user podman config files (can be adjusted)
      containersConfText = ''
        [containers]
        # choose userns="auto" or "host" depending on needs
        userns="auto"
        [engine]
        events_logger="file"
      '';

      storageConfText = ''
        [storage]
        driver = "overlay"
        [storage.options]
        mount_program = "${pkgs.fuse-overlayfs}/bin/fuse-overlayfs"
      '';

      registriesConfText = ''
        [registries.search]
        registries = ["docker.io", "quay.io"]
      '';

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
          dns_enabled = true;
        };
      };

      ########################################################################
      # tmpfiles for each container (existing logic, with extra rootless handling)
      ########################################################################
      systemd.tmpfiles.rules =
        (reduceContainers (acc: servName: servDef: conName: conDef: (
          let
            base = [
              "d /var/lib/selfhosted/${servName}/${conName} 0770 root root"
            ];

            # for volumes create tmpfiles entries as before
            volEntries =
              lib.lists.optionals (builtins.hasAttr "volumes" conDef) (lib.attrsets.foldlAttrs
                (acc: conPath: volDef:
                  let volAttrs = mapVolumeAttrs servName conName conPath volDef;
                  in
                  acc ++ lib.lists.optionals (!volAttrs.isSystemPath) [
                    "d ${volAttrs.hostDir} 0770 ${volDef.volumeOwner} ${volDef.volumeGroup}"
                    "Z ${volAttrs.hostDir} 0770 ${volDef.volumeOwner} ${volDef.volumeGroup}"
                    "A ${volAttrs.hostDir} mask::rwx"
                  ] ++ lib.lists.optionals (builtins.hasAttr "extraPerms" volDef) (
                    (lib.lists.foldl
                      (acc: extraPerms:
                        acc ++ [ "Z ${volDef.hostPath}/${extraPerms.relPath} ${extraPerms.permissions} - - " ])
                      [ ]
                      volDef.extraPerms)
                  )
                ) [ ]
                conDef.volumes);
          in
          acc ++ base ++ volEntries
        )) [ ]
          enabledServices);

      virtualisation.oci-containers.backend = "podman";

      environment.etc = let
        ##############################################################################
        # Environment / etc entries: build /etc/subuid and /etc/subgid covering rootless containers
        # Only include entries for containers that have rootless = true
        ##############################################################################
        # create lists of rootless containers (as "ctr-serv-con")
        rootlessContainersList =
          lib.attrsets.foldlAttrs
            (acc: servName: servDef:
              acc ++ (lib.attrsets.foldlAttrs
                (acc2: conName: conDef:
                  if (builtins.hasAttr "rootless" conDef && conDef.rootless == true)
                  then acc2 ++ [ "${servName}-${conName}" ] else acc2
                ) [ ] servDef.containers)
            ) [ ]
            enabledServices;

        # build /etc/subuid and /etc/subgid contents (each line: username:start:count)
        subuid_lines = lib.lists.imap0 (idx: fullName:
          let
            userName = "ctr-${fullName}";
          in "${userName}:${mkSubRange idx}"
        ) (rootlessContainersList);

        subuid_text = lib.concatStringsSep "\n" subuid_lines;
        subgid_text = subuid_text;
      in {
        "subuid".text = subuid_text;
        "subgid".text = subgid_text;
      };

      ##############################################################################
      # Generate users and groups for rootless containers
      ##############################################################################
      users.groups = lib.attrsets.foldlAttrs
        (acc: servName: servDef:
          acc //
          (lib.attrsets.foldlAttrs (a: conName: conDef:
            if (builtins.hasAttr "rootless" conDef && conDef.rootless == true)
            then a // {
              "${containerSystemUser servName conName}" = {
                gid = mkUidFromIndex (containerIndex servName conName);
              };
            } else a
          ) { } servDef.containers)
        )
        { }
        enabledServices;

      users.users = lib.attrsets.foldlAttrs
        (acc: servName: servDef:
          acc //
          (lib.attrsets.foldlAttrs (a: conName: conDef:
            if (builtins.hasAttr "rootless" conDef && conDef.rootless == true)
            then a // {
              "${containerSystemUser servName conName}" = {
                isSystemUser = true;
                uid = mkUidFromIndex (containerIndex servName conName);
                group = containerSystemUser servName conName;
                description = "Rootless Podman user for ${servName}-${conName}";
                home = containerRuntimeDir servName conName;
              };
            } else a
          ) { } servDef.containers)
        )
        { }
        enabledServices;

      ##############################################################################
      # Podman per-container definitions (containers, mounts, labels, volumes, secrets)
      ##############################################################################
      virtualisation.oci-containers.containers =
        (reduceContainers
          (acc: servName: servDef: conName: conDef: (
            let
              fullName = "${servName}-${conName}";
              containerUser = if builtins.hasAttr "containerUser" conDef then conDef.containerUser else "root:root";
              systemUser = containerSystemUser servName conName;
              idx = containerIndex servName conName;
              uid = mkUidFromIndex idx;
              runtimeDir = containerRuntimeDir servName conName;
              persistDir = containerPersistDir servName conName;

              ################################################################################
              # Build labels (as before) — unchanged
              ################################################################################
              baseLabels = {
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
                  "traef.http.docker.network" = "${reverseProxyNetwork}";
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
                };
              labels = baseLabels // lib.attrsets.optionalAttrs (builtins.hasAttr "extraLabels" conDef) conDef.extraLabels;

              ################################################################################
              # volumes: map using mapVolumeAttrs as before; for rootless containers we set up
              # bind mount points under /var/lib/selfhosted/... and chown these to the system user
              ################################################################################
              volumesList = lib.lists.optionals
                (builtins.hasAttr "volumes" conDef)
                (lib.mapAttrsToList
                  (containerPath: volDef:
                    let
                      volAttrs = mapVolumeAttrs servName conName containerPath volDef;
                      isRootless = (builtins.hasAttr "rootless" conDef && conDef.rootless == true);
                      # For rootless containers, we will chown hostDir to the system user so the container can access it.
                      # This handles the common case where the container expects root:root inside (mapped to system user).
                      # More complex UID/GID mapping for arbitrary internal UIDs/GIDs needs newuidmap/newgidmap or explicit mapping tools.
                      hostDir = volAttrs.hostDir;
                      varDir = volAttrs.varDir;
                    in
                    if builtins.hasAttr "mountOptions" volDef
                    then
                      "${varDir}:${containerPath}:${volDef.mountOptions}"
                    else
                      "${varDir}:${containerPath}"
                  )
                  conDef.volumes);

              ################################################################################
              # environment/entrypoint/cmd logic unchanged
              ################################################################################
            in
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

                labels = labels;

                environment = lib.attrsets.optionalAttrs
                  (builtins.hasAttr "environment" conDef)
                  conDef.environment //
                lib.attrsets.optionalAttrs
                  (builtins.hasAttr "environment" servDef)
                  servDef.environment;

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

                volumes = volumesList;

                log-driver = "journald";

                extraOptions =
                  lib.lists.optionals (builtins.hasAttr "extraOptions" conDef)
                    conDef.extraOptions ++

                  lib.lists.optionals (builtins.hasAttr "secrets" conDef)
                    (lib.attrsets.mapAttrsToList
                      (secretName: secretDef:
                        let
                          secretAttrs = mapSecretAttrs servName conName secretName secretDef;
                        in
                        "--secret=${secretAttrs.secretProperName},type=env,target=${secretAttrs.secretEnvName}"
                      )
                      conDef.secrets) ++

                  lib.lists.optionals
                    (builtins.hasAttr "proxy" conDef ||
                    builtins.hasAttr "proxies" conDef)
                    [ "--network=${reverseProxyNetwork}" ] ++

                  lib.lists.optionals
                    (builtins.hasAttr "networks" conDef &&
                    builtins.hasAttr "external" conDef.networks &&
                    conDef.networks.external)
                    [ "--network=${servName}-external" ] ++

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

      ##############################################################################
      # systemd services for mounts and secrets remain largely unchanged, but we
      # ensure they run before rootless container services as needed.
      ##############################################################################
      systemd.services =
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
                        mkdir -p ${volAttrs.varDir}
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
        (
          (reduceContainers (acc: servName: servDef: conName: conDef: (
            acc // {
              "podman-${servName}-${conName}" = let
                fullName = "${servName}-${conName}";
                containerUser = if builtins.hasAttr "containerUser" conDef then conDef.containerUser else "root:root";
                systemUser = containerSystemUser servName conName;
                idx = containerIndex servName conName;
                uid = mkUidFromIndex idx;
                runtimeDir = containerRuntimeDir servName conName;
                persistDir = containerPersistDir servName conName;

                ################################################################################
                # volumes: map using mapVolumeAttrs as before; for rootless containers we set up
                # bind mount points under /var/lib/selfhosted/... and chown these to the system user
                ################################################################################
                volumesList = lib.lists.optionals
                  (builtins.hasAttr "volumes" conDef)
                  (lib.mapAttrsToList
                    (containerPath: volDef:
                      let
                        volAttrs = mapVolumeAttrs servName conName containerPath volDef;
                        isRootless = (builtins.hasAttr "rootless" conDef && conDef.rootless == true);
                        # For rootless containers, we will chown hostDir to the system user so the container can access it.
                        # This handles the common case where the container expects root:root inside (mapped to system user).
                        # More complex UID/GID mapping for arbitrary internal UIDs/GIDs needs newuidmap/newgidmap or explicit mapping tools.
                        hostDir = volAttrs.hostDir;
                        varDir = volAttrs.varDir;
                      in
                      if builtins.hasAttr "mountOptions" volDef
                      then
                        "${varDir}:${containerPath}:${volDef.mountOptions}"
                      else
                        "${varDir}:${containerPath}"
                    )
                    conDef.volumes);
              in {
                ##############################################
                # systemd unit adjustments for rootless vs rootful
                ##############################################
                # For rootless containers: the generated podman service will run as the per-container system user,
                # create the runtime/persist dirs, install per-user podman config files (from store), chown the
                # prepared varDir/hostDir entries to that user, and then run podman via sudo -u as that user.
                #
                # For rootful containers: keep the previous rootful podman service behavior.
                #
                serviceConfig = if (builtins.hasAttr "rootless" conDef && conDef.rootless == true) then {
                  # run the podman process as the system user
                  User = systemUser;
                  Group = systemUser;

                  # Prestart: ensure runtime/persist dirs exist and copy in config templates, and chown volume hostDirs
                  ExecStartPre = lib.strings.concatStringsSep "\n" ([
                    ''
                      mkdir -p ${runtimeDir} ${persistDir}
                      install -m 600 ${pkgs.writeText "containers.conf" containersConfText} ${runtimeDir}/containers.conf
                      install -m 600 ${pkgs.writeText "storage.conf" storageConfText} ${runtimeDir}/storage.conf
                      install -m 600 ${pkgs.writeText "registries.conf" registriesConfText} ${runtimeDir}/registries.conf
                      chown -R ${systemUser}:${systemUser} ${runtimeDir} ${persistDir} || true
                    ''
                  ] ++
                  # For each volume, ensure varDir exists and chown it to systemUser
                  (if (builtins.hasAttr "volumes" conDef)
                    then lib.attrsets.foldlAttrs
                      (acc2: cPath: volDef:
                        let volAttrs = mapVolumeAttrs servName conName cPath volDef;
                        in acc2 ++ [
                          ''
                            mkdir -p ${volAttrs.varDir}
                            chown -R ${systemUser}:${systemUser} ${volAttrs.varDir} || true
                          ''
                        ]
                      ) [ ] conDef.volumes
                    else [ ] )
                  );

                  ExecStart = lib.mkForce ''
                    ${pkgs.sudo}/bin/sudo -u ${systemUser} \
                      ${pkgs.podman}/bin/podman run \
                        --name ${servName}-${conName} \
                        --cgroup-manager=cgroupfs \
                        --storage-driver=overlay \
                        --root ${persistDir}/root \
                        --runroot ${persistDir}/run \
                        ${if (builtins.hasAttr "volumes" conDef) then (lib.concatStringsSep " " (lib.lists.map (v: "--volume " + v) volumesList)) else ""} \
                        ${if (builtins.hasAttr "ports" conDef) then (lib.concatStringsSep " " (lib.mapAttrsToList (cp: hp: if hp.hostPort != null then "--publish ${hp.hostPort}:${cp}:${hp.protocol}" else "") (conDef.ports or {}))) else ""} \
                        ${lib.concatStringsSep " " (lib.lists.concat [
                          (if builtins.hasAttr "entrypoint" conDef then [ "--entrypoint '${conDef.entrypoint}'" ] else [])
                        ])} \
                        ${conDef.image} ${lib.concatStringsSep " " (conDef.cmd or [])}
                  '';

                  ExecStartPost = ''
                    ${pkgs.sudo}/bin/sudo -u ${systemUser} ${pkgs.podman}/bin/podman network connect global ${servName}-${conName} || true
                  '';

                  ExecStopPost = lib.mkForce "${pkgs.podman}/bin/podman rm -f ${servName}-${conName} || true";
                  Restart = lib.mkOverride 500 "always";
                } else {
                  # rootful default serviceConfig (unchanged)
                  ExecStart = lib.mkForce ''
                    ${pkgs.podman}/bin/podman run --rm --name ${servName}-${conName} \
                      ${if (builtins.hasAttr "ports" conDef) then (lib.concatStringsSep " " (lib.mapAttrsToList (cp: hp: if hp.hostPort != null then "--publish ${hp.hostPort}:${cp}:${hp.protocol}" else "") (conDef.ports or {}))) else ""} \
                      ${if (builtins.hasAttr "volumes" conDef) then (lib.concatStringsSep " " (lib.lists.map (v: "--volume " + v) (lib.mapAttrsToList (cp: vd: let va = mapVolumeAttrs servName conName cp vd; in if vd.mountOptions != null then "${va.varPath}:${cp}:${vd.mountOptions}" else "${va.varPath}:${cp}" ) (conDef.volumes)))) else ""} \
                      ${conDef.image} ${lib.concatStringsSep " " (conDef.cmd or [])}
                  '';
                  ExecStopPost = lib.mkForce "${pkgs.podman}/bin/podman rm -f ${servName}-${conName} || true";
                  Restart = lib.mkOverride 500 "always";
                } //
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
        (reduceContainers
          (acc: servName: servDef: conName: conDef: (
            acc //
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
