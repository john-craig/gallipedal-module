# Gallipedal v2 Design

The actual service definitions can be like so:

```
ports = [
    {
        containerPort = "80";
        protocol = "tcp";
    }
    {
        containerPort = "22";
        protocol = "tcp";
    }
];
```

Then this should result in an option like this:

```
ports = lib.mkOption {
    type = lib.types.submodule {
        options = {
            "80" = lib.mkOption {
                type = lib.types.submodule {
                    options = {
                        hostPort = lib.mkOption {
                            type = lib.types.str;
                            description = "The host port to be used for mapping";
                        };

                        protocol = lib.mkOption {
                            type = lib.types.enum [ "tcp" "udp" ];
                            default = "tcp";
                        };
                    };
                };
            };

            "22" = lib.mkOption {
                type = lib.types.submodule {
                    options = {
                        hostPort = lib.mkOption {
                            type = lib.types.str;
                            description = "The host port to be used for mapping";
                        };

                        protocol = lib.mkOption {
                            type = lib.types.enum [ "tcp" "udp" ];
                            default = "tcp";
                        };
                    };
                };
            };
        };
    };
}
```

Then when setting these options, someone could do the following:
```
ports."80".hostPort = "55";
ports."22".hostPort = "66";
```

but if necessary, they could instead do,

```
ports."80" = {
    hostPort = "55";
    protocol = "udp";
};
```

in order to override that value.