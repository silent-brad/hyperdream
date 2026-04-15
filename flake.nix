{
  description = "Hyperdream — MirageOS/Datastar web framework";

  inputs = {
    opam-nix.url = "github:tweag/opam-nix";
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.follows = "opam-nix/nixpkgs";
    # remove flake=false?
    datastar-sdk = {
      url = "github:silent-brad/datastar-sdk-ocaml";
      flake = false;
    };
  };

  outputs =
    {
      self,
      flake-utils,
      opam-nix,
      nixpkgs,
      datastar-sdk,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        on = opam-nix.lib.${system};

        devPackagesQuery = {
          ocaml-lsp-server = "*";
          ocamlformat = "*";
          utop = "*";
          merlin = "*";
        };

        query = devPackagesQuery // {
          ocaml-base-compiler = "5.2.1";
        };

        # Build a local opam repo from the datastar SDK source so opam-nix
        # can resolve the dependency.
        datastarRepo = on.makeOpamRepo datastar-sdk;

        scope = on.buildOpamProject' {
          repos = [
            datastarRepo
            on.opamRepository
          ];
        } ./. query;

        overlay = final: prev: {
          hyperdream = prev.hyperdream.overrideAttrs (oa: {
            nativeBuildInputs = (oa.nativeBuildInputs or [ ]) ++ [ pkgs.nushell ];
            doNixSupport = false;
          });
        };

        scope' = scope.overrideScope overlay;
        main = scope'.hyperdream;
        devPackages = builtins.attrValues (pkgs.lib.getAttrs (builtins.attrNames devPackagesQuery) scope');
      in
      {
        legacyPackages = scope';

        packages.default = main;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ main ];
          buildInputs = devPackages ++ [ pkgs.nushell ];
        };
      }
    );
}
