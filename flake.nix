{
  description = "MCP server for grafana";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    gomod2nix = {
      url = "github:nix-community/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = {
    self,
    nixpkgs,
    gomod2nix,
    systems,
    ...
  }: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
    pkgsFor = forEachSystem (system:
      import nixpkgs {
        inherit system;
        overlays = [
          gomod2nix.overlays.default
        ];
      });
  in {
    formatter = forEachSystem (system: pkgsFor.${system}.alejandra);

    devShells = forEachSystem (system: let
      goEnv = pkgsFor.${system}.mkGoEnv {pwd = ./.;};
    in {
      default = pkgsFor.${system}.mkShell {
        packages = [
          # goEnv
          gomod2nix.packages.${system}.default
          (pkgsFor.${system}.writeScriptBin "mcp-inspector" ''
            #!${pkgsFor.${system}.bash}/bin/bash
            export PATH="${pkgsFor.${system}.nodejs_23}/bin:$PATH"
            ${pkgsFor.${system}.nodejs_23}/bin/npx -y @modelcontextprotocol/inspector nix run
          '')
        ];
      };
    });

    packages = forEachSystem (system: {
      default = pkgsFor.${system}.buildGoApplication {
        pname = "mcp-grafana";
        version = "0.1.0";
        pwd = ./.;
        src = ./.;
        modules = ./gomod2nix.toml;
      };
    });

    apps = forEachSystem (system: {
      default = {
        type = "app";
        program = "${self.packages.${system}.default}/bin/mcp-grafana";
      };
    });
  };
}
