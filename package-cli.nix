{ lib
, buildNpmPackage
, fetchurl
, importNpmLock
, makeWrapper
, nodejs_22
, codexSupport ? true
, codex
}:

let
  # Use the mcp-server's package.json and package-lock.json
  packageJson = lib.importJSON ./npm/package.json;
  packageJsonForNpm = builtins.removeAttrs packageJson [ "overrides" ];
  packageLockJson = lib.importJSON ./npm/package-lock.json;

  # The CLI binary path
  binPath =
    let
      rawBinPath =
        if lib.isAttrs packageJson.bin then
          packageJson.bin.llm-wiki-mcp
        else
          packageJson.bin;
    in
    lib.removePrefix "./" rawBinPath;

  binCjsPath =
    if lib.hasSuffix ".mjs" binPath then
      "${lib.removeSuffix ".mjs" binPath}.cjs"
    else
      null;

in
buildNpmPackage rec {
  pname = "llm-wiki-mcp";
  version = "0.6.13";
  nodejs = nodejs_22;

  src = fetchurl {
    url = "https://registry.npmjs.org/llm-wiki-mcp/-/llm-wiki-mcp-${version}.tgz";
    hash = "sha512-PLACEHOLDER_HASH";
  };

  sourceRoot = "package";

  npmDeps = importNpmLock {
    package = packageJsonForNpm;
    packageLock = packageLockJson;
    fetcherOpts = {
      "node_modules/@effect/platform-node" = {
        name = "platform-node.tgz";
      };
      "node_modules/@effect/platform-node-shared" = {
        name = "platform-node-shared.tgz";
      };
      "node_modules/@effect/sql-sqlite-bun" = {
        name = "sql-sqlite-bun.tgz";
      };
      "node_modules/effect" = {
        name = "effect.tgz";
      };
    };
  };

  npmConfigHook = importNpmLock.npmConfigHook;
  nativeBuildInputs = [ makeWrapper ];
  dontNpmBuild = true;

  postPatch = ''
    cp ${./npm/package.json} package.json
    cp ${./npm/package-lock.json} package-lock.json

    ${lib.optionalString (packageJson ? overrides) ''
      node -e '
        const fs = require("fs");
        const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
        delete pkg.overrides;
        fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
      '
    ''}

    bin_path=${lib.escapeShellArg binPath}
    if [ ! -f "$bin_path" ]; then
      echo "missing CLI entrypoint: $bin_path" >&2
      exit 1
    fi

    sed -i "s/var version = \\\".*\\\";/var version = \\\"${version}\\\";/" "$bin_path"

    ${lib.optionalString (binCjsPath != null) ''
      bin_cjs_path=${lib.escapeShellArg binCjsPath}
      if [ -f "$bin_cjs_path" ]; then
        sed -i "s/var version = \\\".*\\\";/var version = \\\"${version}\\\";/" "$bin_cjs_path"
      fi
    ''}
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/node_modules/llm-wiki-mcp $out/bin
    cp -r . $out/lib/node_modules/llm-wiki-mcp

    makeWrapper ${nodejs_22}/bin/node $out/bin/llm-wiki-mcp \
      --add-flags "$out/lib/node_modules/llm-wiki-mcp/${binPath}" \
      ${lib.optionalString codexSupport ''
        --prefix PATH : "${lib.makeBinPath [ codex ]}"
      ''}

    runHook postInstall
  '';

  meta = with lib; {
    description = "LLM Wiki MCP Server CLI";
    homepage = "https://github.com/nashsu/llm_wiki";
    license = licenses.elastic-2-0;
    mainProgram = "llm-wiki-mcp";
    platforms = platforms.unix;
  };
}