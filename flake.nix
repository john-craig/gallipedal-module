{
  description = "Gallipedal Self-Hosting Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    gallipedal-library.url = "git+https://gitea.chiliahedron.wtf/chiliahedron/gallipedal-library";
    gallipedal-library.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = { self, gallipedal-library, nixpkgs }@inputs: {

    nixosModules = {
      gallipedal = (import ./. inputs);
    };

  };
}
