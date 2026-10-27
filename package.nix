{ lib
, stdenv
, stdenvNoCC
, appimageTools
, fetchurl
, makeWrapper
, unzip
, codexSupport ? true
, codex
}:

let
  pname = "llm-wiki";
  version = "0.6.13";
  linuxHash = "sha256-PLACEHOLDER_LINUX_HASH";
  darwinX64Hash = "sha256-PLACEHOLDER_DARWIN_X64_HASH";
  darwinArm64Hash = "sha256-PLACEHOLDER_DARWIN_ARM64_HASH";

  commonMeta = {
    description = "LLM Wiki - A personal knowledge base that builds itself";
    homepage = "https://github.com/nashsu/llm_wiki";
    changelog = "https://github.com/nashsu/llm_wiki/releases/tag/v${version}";
    downloadPage = "https://github.com/nashsu/llm_wiki/releases";
    license = lib.licenses.elastic-2-0;
    mainProgram = pname;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };

  linuxPackage =
    let
      src = fetchurl {
        url = "https://github.com/nashsu/llm_wiki/releases/download/v${version}/llm-wiki-linux.AppImage";
        hash = linuxHash;
      };

      appimageContents = appimageTools.extractType2 {
        inherit pname version src;
      };
    in
    appimageTools.wrapType2 {
      inherit pname version src;
      nativeBuildInputs = [ makeWrapper ];

      extraInstallCommands = ''
        mkdir -p "$out/share"

        if [ -d ${appimageContents}/usr/share ]; then
          cp -r ${appimageContents}/usr/share/* "$out/share/"
        fi

        desktop_file="$(find "$out/share" -type f -name '*.desktop' | head -n 1 || true)"
        if [ -z "$desktop_file" ]; then
          desktop_source="$(find ${appimageContents} -maxdepth 2 -type f -name '*.desktop' | head -n 1 || true)"
          if [ -n "$desktop_source" ]; then
            desktop_file="$out/share/applications/$(basename "$desktop_source")"
            install -Dm444 "$desktop_source" "$desktop_file"
          fi
        fi

        if [ -n "$desktop_file" ]; then
          desktop_basename="$(basename "$desktop_file")"

          sed -i \
            -e 's|Exec=AppRun|Exec=${pname}|g' \
            -e 's|Exec=AppRun %U|Exec=${pname} %U|g' \
            -e 's|TryExec=AppRun|TryExec=${pname}|g' \
            -e 's|^StartupWMClass=.*$|StartupWMClass=llm-wiki|g' \
            "$desktop_file"

          wrapProgram "$out/bin/${pname}" \
            --set CHROME_DESKTOP "$desktop_basename" \
            --prefix XDG_DATA_DIRS : "$out/share" \
            ${lib.optionalString codexSupport ''
              --prefix PATH : "${lib.makeBinPath [ codex ]}"
            ''}
        fi

        if [ -f ${appimageContents}/.DirIcon ]; then
          install -Dm444 ${appimageContents}/.DirIcon "$out/share/pixmaps/${pname}.png"
        fi
      '';

      meta = commonMeta;
    };

  darwinAppName = "LLM Wiki.app";
  darwinExecutable = "LLM Wiki";
  darwinAsset =
    if stdenv.hostPlatform.isAarch64 then
      "llm-wiki-macos-arm64.dmg"
    else
      "llm-wiki-macos-x64.dmg";
  darwinHash =
    if stdenv.hostPlatform.isAarch64 then
      darwinArm64Hash
    else
      darwinX64Hash;

  darwinPackage = stdenvNoCC.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://github.com/nashsu/llm_wiki/releases/download/v${version}/${darwinAsset}";
      hash = darwinHash;
    };

    nativeBuildInputs = [
      makeWrapper
      unzip
    ];

    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      # Extract dmg and find the app
      7z x $src -o$TMPDIR/dmg
      app_path=$(find $TMPDIR/dmg -name "*.app" -maxdepth 2 | head -n1)
      if [ -n "$app_path" ]; then
        cp -r "$app_path" "$out/Applications/LLM Wiki.app"
      fi

      makeWrapper \
        "$out/Applications/LLM Wiki.app/Contents/MacOS/LLM Wiki" \
        "$out/bin/${pname}" \
        ${lib.optionalString codexSupport ''
          --prefix PATH : "${lib.makeBinPath [ codex ]}"
        ''}

      runHook postInstall
    '';

    meta = commonMeta;
  };
in
if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64 then
  linuxPackage
else if stdenv.hostPlatform.isDarwin then
  darwinPackage
else
  throw "llm-wiki desktop is only packaged for x86_64-linux, x86_64-darwin, and aarch64-darwin"