{
  description = "Gallipedal Self-Hosting Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    services-library.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/services-library";
  };

  outputs = { self, services-library, nixpkgs }: {

    nixosModules = {
      gallipedal = (import ./. inputs);
    }

  };
}
