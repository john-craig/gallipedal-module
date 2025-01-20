{ lib, ... }:
rec {
  mkSubmodule = submodule:
    lib.types.submodule {
      options = submodule;
    };

  foldListToOptions = func: defnList:
    (lib.lists.foldl
      (acc: defn:
        acc // (func defn)
      )
      { }
      defnList);

  mkPortOptions = portDefs:
    foldListToOptions
      (portDef: {
        "${portDef.containerPort}" = lib.mkOption {
          type = mkSubmodule {
            hostPort = lib.mkOption {
              type = lib.types.str;
              description = "The host port to be used for mapping";
              example = "8080";
            };

            protocol = lib.mkOption {
              type = lib.types.enum [ "tcp" "udp" ];
              default = "${portDef.protocol}";
              description = "The protocol for the port";
              example = "tcp";
            };
          };
        };
      })
      portDefs;

  mkVolumeOptions = volumeDefs:
    foldListToOptions
      (volumeDef: {
        "${volumeDef.containerPath}" = lib.mkOption {
          type = mkSubmodule {
            hostPath = lib.mkOption {
              type = lib.types.str;
              description = "The host path of the volume mapping";
              example = "/srv/hostpath";
            };

            mountOptions = lib.mkOption {
              type = lib.types.enum [ "rw" "ro" ];
              default = "${volumeDef.mountOptions}";
              description = "Mount permissions for the volume";
              example = "ro";
            };

            volumeType = lib.mkOption {
              type = lib.types.enum [ "directory" "file" ];
              default = "${volumeDef.volumeType}";
              description = "Whether the mountpoint is a directory or a file.";
              example = "directory";
            };

            extraPerms = lib.mkOption {
              description = "A list of paths relative to this volume mount point to which specified permissions should be applied.";
              default =
                if builtins.hasAttr "extraPerms" volumeDef
                then volumeDef.extraPerms
                else [ ];

              type = lib.types.listOf lib.types.attrs;
              # type = lib.types.listOf (mkSubmodule {
              #   relPath = lib.mkOption {
              #     type = lib.types.str;
              #     example = "config/file.txt";
              #   };

              #   permissions = {
              #     type = lib.types.str;
              #     example = "777";
              #   };
              # });
            };
          };
        };
      })
      volumeDefs;

  mkEnvironmentOptions = envVars:
    foldListToOptions
      (envVarName: {
        "${envVarName}" = lib.mkOption {
          type = lib.types.str;
        };
      })
      envVars;

  mkSecretOptions = secretsList:
    foldListToOptions
      (secretName: {
        "${secretName}" = lib.mkOption {
          description = "Path to file containing value for secret ${secretName}";
          type = lib.types.str;
        };
      })
      secretsList;

  mkContainerOptions = conDef: {
    image = lib.mkOption {
      type = lib.types.str;
      default = conDef.image;
    };

    containerUser = lib.mkOption {
      type = lib.types.str;
      default = "root:root";
    };

    extraLabels = lib.mkOption {
      type = lib.types.attrs;
      default =
        if builtins.hasAttr "extraLabels" conDef
        then conDef.extraLabels
        else { };
    };

    extraOptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        if builtins.hasAttr "extraOptions" conDef
        then conDef.extraOptions
        else [ ];
    };

    networks = lib.mkOption {
      type = lib.types.attrs;
      default =
        if builtins.hasAttr "networks" conDef
        then conDef.networks
        else { };
    };

    dependsOn = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default =
        if builtins.hasAttr "dependsOn" conDef
        then conDef.dependsOn
        else [ ];
    };


    # TODO: This will be handled in a separate module later
    proxies = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default =
        if builtins.hasAttr "proxies" conDef
        then conDef.proxies
        else [ ];
    };
  } // lib.attrsets.optionalAttrs (builtins.hasAttr "entrypoint" conDef) {
    entrypoint = lib.mkOption {
      type = lib.types.str;
      default = conDef.entrypoint;
    };
  } // lib.attrsets.optionalAttrs (builtins.hasAttr "cmd" conDef) {
    cmd = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = conDef.cmd;
    };
  } // lib.attrsets.optionalAttrs (builtins.hasAttr "environment" conDef) {
    environment = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        options = (mkEnvironmentOptions conDef.environment);
      };
    };
  } // lib.attrsets.optionalAttrs (builtins.hasAttr "secrets" conDef) {
    secrets = lib.mkOption {
      default = null;
      type = lib.types.submodule {
        options = (mkSecretOptions conDef.secrets);
      };
    };
  } // lib.attrsets.optionalAttrs (builtins.hasAttr "ports" conDef) {
    ports = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        options = (mkPortOptions conDef.ports);
      };
    };
  } // lib.attrsets.optionalAttrs (builtins.hasAttr "volumes" conDef) {
    volumes = lib.mkOption {
      default = { };
      type = lib.types.submodule {
        options = (mkVolumeOptions conDef.volumes);
      };
    };
  };

  mkServiceOptions = servName: servDef: {
    enable = lib.mkEnableOption "for self-hosted service ${servName}";

    containers = lib.mkOption {
      type = lib.types.submodule {
        options = (lib.attrsets.foldlAttrs
          (acc: conName: conDef:
            acc // {
              "${conName}" = lib.mkOption {
                type = lib.types.submodule {
                  options = (mkContainerOptions conDef);
                };
              };
            })
          { }
          servDef.containers);
      };
    };
  };
}
