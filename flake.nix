{
  description = "QNTX MeiliSearch Plugin - Search provider plugin for QNTX";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # The QNTX this plugin is built against: the tag Cargo.toml names.
    qntx = {
      url = "github:teranos/QNTX/v0.44.0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, qntx }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        # Cargo.lock pins QNTX's crates to one rev; the qntx input is that
        # rev or this flake refuses to build, so the two cannot drift apart.
        lock = builtins.fromTOML (builtins.readFile ./Cargo.lock);
        qntxGrpc = pkgs.lib.findFirst (p: p.name == "qntx-grpc")
          (throw "Cargo.lock holds no qntx-grpc") lock.package;
        lockedRev = pkgs.lib.last (pkgs.lib.splitString "#" qntxGrpc.source);
        qntxSrc =
          if lockedRev == qntx.rev then qntx
          else throw "Cargo.lock pins qntx-grpc at ${lockedRev} but the flake's qntx input is ${qntx.rev}: point both at the same QNTX tag";

        # QNTX's crates (qntx-grpc, qntx-proto, qntx-ats) are Cargo's git
        # dependency on teranos/QNTX; nix fetches the rev Cargo.lock pins
        # with its own git fetcher, so there is no hash to keep here.
        cargoLock = {
          lockFile = ./Cargo.lock;
          allowBuiltinFetchGit = true;
        };

        # Nix vendors each QNTX crate on its own, away from the tree
        # qntx-proto's build.rs reads ../../plugin/grpc/protocol from; the
        # protos come from the qntx input instead.
        QNTX_PROTO_DIR = "${qntxSrc}/plugin/grpc/protocol";

        qntx-meili = pkgs.rustPlatform.buildRustPackage {
          pname = "qntx-meili";
          version = self.rev or "dev";
          src = ./.;

          inherit cargoLock QNTX_PROTO_DIR;

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

          inherit cargoLock QNTX_PROTO_DIR;

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
