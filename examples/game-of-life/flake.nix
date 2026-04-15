{
  description = "Hyperdream example: game-of-life";

  inputs = {
    hyperdream.url = "path:../..";
    nixpkgs.follows = "hyperdream/nixpkgs";
    flake-utils.follows = "hyperdream/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      hyperdream,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        scope = hyperdream.legacyPackages.${system};

        ocamlDeps = [
          scope.hyperdream
          scope.paf
          scope.tcpip
          scope.lwt
          scope.jingoo
          scope.h1
          scope.datastar
          scope.uri
          scope.digestif
          scope.base64
          scope.mirage-crypto-rng
          scope.yojson
          scope.ocamlfind
        ];

        example = pkgs.stdenv.mkDerivation {
          pname = "hyperdream-example-game-of-life";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [
            pkgs.nushell
            scope.ocaml
            scope.dune
          ];

          buildInputs = ocamlDeps;

          preBuild = ''
            export OCAMLPATH="${scope.hyperdream}/lib/ocaml/5.2.1/site-lib''${OCAMLPATH:+:}$OCAMLPATH"
          '';

          buildPhase = ''
            runHook preBuild
            dune build ./main.exe
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin
            cp _build/default/main.exe $out/bin/game-of-life
            runHook postInstall
          '';
        };
      in
      {
        packages.default = example;

        devShells.default = pkgs.mkShell {
          inputsFrom = [ example ];
          buildInputs = [
            scope.ocaml-lsp-server
            scope.ocamlformat
            scope.utop
            scope.merlin
          ];
        };
      }
    );
}
