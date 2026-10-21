{
  description = "QNTX MeiliSearch Plugin - Search provider plugin for QNTX";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        # QNTX's crates (qntx-grpc, qntx-proto, qntx-ats) are Cargo's git
        # dependency on teranos/QNTX, pinned to one rev in Cargo.lock; nix
        # fetches that rev with its own git fetcher, so no hash to keep here.
        cargoLock = {
          lockFile = ./Cargo.lock;
          allowBuiltinFetchGit = true;
        };

        qntx-meili = pkgs.rustPlatform.buildRustPackage {
          pname = "qntx-meili";
          version = self.rev or "dev";
          src = ./.;

          inherit cargoLock;

          buildInputs = with pkgs; [
            protobuf
            openssl
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
            protobuf
          ];
        };

        qntx-meili-clippy = pkgs.rustPlatform.buildRustPackage {
          pname = "qntx-meili-clippy";
          version = self.rev or "dev";
          src = ./.;

          inherit cargoLock;

          nativeBuildInputs = with pkgs; [
            pkg-config
            protobuf
            clippy
          ];

          buildInputs = with pkgs; [
            protobuf
            openssl
          ];

          buildPhase = ''
            cargo clippy --all-targets -- -D warnings
          '';

          installPhase = ''
            mkdir -p $out
            echo "Clippy passed" > $out/result
          '';

          doCheck = false;
        };
      in
      {
        packages = {
          default = qntx-meili;
          qntx-meili = qntx-meili;
        };

        checks = {
          clippy = qntx-meili-clippy;
        };

        apps.default = {
          type = "app";
          program = "${qntx-meili}/bin/qntx-meili";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustc
            cargo
            rustfmt
            clippy
            pkg-config
            protobuf
            openssl
          ];
        };
      });
}
