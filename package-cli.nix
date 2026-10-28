{ lib
, buildNpmPackage
, fetchFromGitHub
, importNpmLock
, makeWrapper
, nodejs_22
, codexSupport ? true
, codex
}:

let
  version = "0.6.13";

  # Fetch the source from GitHub to get the mcp-server package.json and package-lock.json
  src = fetchFromGitHub {
    owner = "nashsu";
    repo = "llm_wiki";
    rev = "v${version}";
    sha256 = "sha256-Zgh5N+elUFW0GUFuQO1t6oTEKWxrqb4D3iPn9TmzfQc=";
  };

  packageJson = lib.importJSON "${src}/mcp-server/package.json";
  packageJsonForNpm = builtins.removeAttrs packageJson [ "overrides" ];
  packageLockJson = lib.importJSON "${src}/mcp-server/package-lock.json";

  binPath =
    let
      rawBinPath =
        if lib.isAttrs packageJson.bin then
          builtins.getAttr "llm-wiki-mcp" packageJson.bin
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

  inherit src;

  # NOTE: no `npmRoot` here. The custom unpackPhase below flattens
  # ${src}/mcp-server into the build root; importNpmLock.npmConfigHook
  # would `pushd $npmRoot` into a non-existent directory if it were set.

  npmDeps = importNpmLock {
    package = packageJsonForNpm;
    packageLock = packageLockJson;
  };

  # Use importNpmLock's offline hook instead of the default
  # npmHooks.npmConfigHook: it registers itself on postConfigureHooks,
  # switches npm to offline mode, installs node_modules from the
  # store-patched package-lock.json in npmDeps (no network needed),
  # and restores the original package.json afterwards.
  # Requires configurePhase to run `runHook postConfigure` to fire.
  npmConfigHook = importNpmLock.npmConfigHook;
  nativeBuildInputs = [ makeWrapper ];
  dontNpmBuild = true;

  # Use unpackPhase to copy the source to a writable location
  unpackPhase = ''
    runHook preUnpack

    # Copy the mcp-server directory to the build directory
    cp -r ${src}/mcp-server/* .

    runHook postUnpack
  '';

  configurePhase = ''
    runHook preConfigure

    # Remove overrides from package.json
    ${lib.optionalString (packageJson ? overrides) ''
      node -e '
        const fs = require("fs");
        const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
        delete pkg.overrides;
        fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
      '
    ''}

    # Dependencies are installed offline by importNpmLock.npmConfigHook
    # (postConfigure hook above); no network access is needed or allowed.

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    # Build TypeScript
    npm run build

    runHook postBuild
  '';

  installPhase = ''
    # Patch version in built files
    bin_path=${lib.escapeShellArg binPath}
    if [ ! -f "$bin_path" ]; then
      echo "missing CLI entrypoint: $bin_path" >&2
      exit 1
    fi

    # 修复：sed -i 在 $out 只读目录下会失败，改用重定向
    sed "s/var version = \\\".*\\\";/var version = \\\"${version}\\\";/" "$bin_path" > "$bin_path.tmp" && mv "$bin_path.tmp" "$bin_path"

    ${lib.optionalString (binCjsPath != null) ''
      bin_cjs_path=${lib.escapeShellArg binCjsPath}
      if [ -f "$bin_cjs_path" ]; then
        sed "s/var version = \\\".*\\\";/var version = \\\"${version}\\\";/" "$bin_cjs_path" > "$bin_cjs_path.tmp" && mv "$bin_cjs_path.tmp" "$bin_cjs_path"
      fi
    ''}
    
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
    license = licenses.elastic20;
    mainProgram = "llm-wiki-mcp";
    platforms = platforms.linux;
  };
}