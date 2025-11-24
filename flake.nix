{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {system = system;};
      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.beam28Packages.erlang
            pkgs.beam28Packages.rebar3
            pkgs.gleam
            pkgs.http-server
            pkgs.just
            pkgs.nushell
            pkgs.qrrs
          ];
        };
      }
    );
}
