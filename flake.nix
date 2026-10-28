{
  description = "Nix flake for the LLM Wiki desktop app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }: let
    supportedSystems = [
      "x86_64-linux"
    ];
    overlay = final: prev: {
      llm-wiki-desktop = final.callPackage ./package.nix {};
      llm-wiki-cli = final.callPackage ./package-cli.nix {};
      llm-wiki = final.llm-wiki-desktop;
    };
    mkApp = drv: binary: {
      type = "app";
      program = "${drv}/bin/${binary}";
      meta = drv.meta;
    };
  in
    flake-utils.lib.eachSystem supportedSystems
    (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [overlay];
        };
      in {
        packages = {
          default = pkgs.llm-wiki;
          llm-wiki = pkgs.llm-wiki;
          llm-wiki-desktop = pkgs.llm-wiki-desktop;
          llm-wiki-cli = pkgs.llm-wiki-cli;
          llm = pkgs.llm;
        };

        apps = {
          default = mkApp pkgs.llm-wiki "llm-wiki";
          llm-wiki = mkApp pkgs.llm-wiki "llm-wiki";
          llm-wiki-desktop = mkApp pkgs.llm-wiki-desktop "llm-wiki";
          llm-wiki-cli = mkApp pkgs.llm-wiki-cli "llm-wiki-mcp";
          llm = mkApp pkgs.llm "llm";
        };

        checks = {
          llm-wiki-build = pkgs.llm-wiki;
          llm-cli-build = pkgs.llm-wiki-cli;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            jq
            nodejs_22
            nixpkgs-fmt
          ];
        };
      }
    )
    // {
      overlays.default = overlay;
    };
}
