{
  description = "Gallipedal Self-Hosting Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }@inputs: {

    nixosModules = {
      gallipedal = import ./default.nix;
    };

  };
}
