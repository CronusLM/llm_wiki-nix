# llm-wiki-nix

Nix flake for packaging [LLM Wiki](https://github.com/nashsu/llm_wiki) - A personal knowledge base that builds itself.

## Overview

This repository provides Nix packages for the LLM Wiki desktop application and MCP server CLI, built from upstream release artifacts.

**Platform scope:** Linux only (x86_64 AppImage).

## Packages

| Package | Description |
|---------|-------------|
| `llm-wiki` | Desktop application (Linux AppImage only) |
| `llm-wiki-cli` / `llm-wiki-mcp` | MCP Server CLI |

## Usage

### Using the flake

```bash
# Run the desktop app
nix run github:YOUR_USERNAME/llm_wiki-nix

# Run the MCP server CLI
nix run github:YOUR_USERNAME/llm_wiki-nix#llm-wiki-cli

# Or add to your NixOS configuration
{ inputs.llm-wiki-nix.url = "github:YOUR_USERNAME/llm_wiki-nix"; }
```

### Development Shell

```bash
nix develop github:YOUR_USERNAME/llm_wiki-nix
```

## Building Locally

```bash
# Build the desktop app
nix build .#llm-wiki

# Build the CLI
nix build .#llm-wiki-cli

# Run checks
nix flake check
```

## CI/CD

GitHub Actions builds Linux only:

- x86_64-linux AppImage
- Cachix caching for faster builds

Required secrets:
- `CACHIX_AUTH_TOKEN` - Cachix authentication token
- `CACHIX_REPO` - Cachix repository name

## License

This packaging is under MIT license. The upstream LLM Wiki is licensed under Elastic License 2.0 (ELv2).