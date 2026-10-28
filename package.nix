{ lib
, stdenv
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
  linuxX64Hash = "sha256-HE7/A7dJq+F51+tA6wNBaUvFO+hmq6ViC3KR8+QszTA=";
  linuxArm64Hash = "sha256-C0POGV58BbIpPuLTh40n/mImbTxn1At6DelKECQoVLU=";

  # Icon extracted from AppImage
  icon = ./icons/llm-wiki.png;

  commonMeta = {
    description = "LLM Wiki - A personal knowledge base that builds itself";
    homepage = "https://github.com/nashsu/llm_wiki";
    changelog = "https://github.com/nashsu/llm_wiki/releases/tag/v${version}";
    downloadPage = "https://github.com/nashsu/llm_wiki/releases";
    license = lib.licenses.elastic20;
    mainProgram = pname;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    maintainers = [ {
      github = "package-maintainer";
    }];
  };

  linuxX64Package =
    let
      src = fetchurl {
        url = "https://github.com/nashsu/llm_wiki/releases/download/v${version}/LLM.Wiki_0.6.13_amd64.AppImage";
        hash = linuxX64Hash;
      };

      # NOTE: the upstream AppImage bundles an old set of wayland libraries
      # (client/cursor/egl/server). They get loaded first via the bundled
      # WebKit's $ORIGIN runpath and break EGL initialisation against the
      # host GL stack (upstream nashsu/llm_wiki#457). Strip them so the
      # system libwayland from the FHS environment is used instead.
      appimageContents = appimageTools.extract {
        inherit pname version src;
        postExtract = "rm -f $out/usr/lib/libwayland-*";
      };
    in
    appimageTools.wrapAppImage {
      inherit pname version;

      contents = appimageContents;
      nativeBuildInputs = [ makeWrapper ];

      extraInstallCommands = ''
        mkdir -p "$out/share"

        if [ -d ${appimageContents}/share ]; then
          cp -r ${appimageContents}/share/* "$out/share/"
        fi

        # Install the real desktop entries from the extracted AppImage.
        # NOTE: the root-level "LLM Wiki.desktop" in the extract is a
        # symlink to usr/share/applications/...; the real files live in
        # ${appimageContents}/usr/share/applications/ (depth 3).
        if [ -d ${appimageContents}/usr/share/applications ]; then
          mkdir -p "$out/share/applications"
          find ${appimageContents}/usr/share/applications -maxdepth 1 -type f -name '*.desktop' \
            -exec cp {} "$out/share/applications/" \;
        fi

        desktop_file="$(find "$out/share" -type f -name '*.desktop' | head -n 1 || true)"

        if [ -n "$desktop_file" ]; then
          desktop_basename="$(basename "$desktop_file")"

          # 修复：sed -i 在 $out 只读目录下会失败，改用重定向
          sed \
            -e 's|Exec=AppRun|Exec=${pname}|g' \
            -e 's|Exec=AppRun %U|Exec=${pname} %U|g' \
            -e 's|TryExec=AppRun|TryExec=${pname}|g' \
            -e 's|^StartupWMClass=.*$|StartupWMClass=llm-wiki|g' \
            "$desktop_file" > "$desktop_file.tmp" && mv "$desktop_file.tmp" "$desktop_file"

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

        # Install extracted icon
        if [ -f ${icon} ]; then
          install -Dm444 ${icon} "$out/share/icons/hicolor/512x512/apps/${pname}.png"
        fi
      '';

      # Raw upstream AppImage for CI distribution (task-6 takes this path).
      passthru.rawAppImage = src;

      meta = commonMeta;
    };

  linuxArm64Package =
    let
      src = fetchurl {
        url = "https://github.com/nashsu/llm_wiki/releases/download/v${version}/LLM.Wiki_0.6.13_aarch64.AppImage";
        hash = linuxArm64Hash;
      };

      # NOTE: the upstream AppImage bundles an old set of wayland libraries
      # (client/cursor/egl/server). They get loaded first via the bundled
      # WebKit's $ORIGIN runpath and break EGL initialisation against the
      # host GL stack (upstream nashsu/llm_wiki#457). Strip them so the
      # system libwayland from the FHS environment is used instead.
      appimageContents = appimageTools.extract {
        inherit pname version src;
        postExtract = "rm -f $out/usr/lib/libwayland-*";
      };
    in
    appimageTools.wrapAppImage {
      inherit pname version;

      contents = appimageContents;
      nativeBuildInputs = [ makeWrapper ];

      extraInstallCommands = ''
        mkdir -p "$out/share"

        if [ -d ${appimageContents}/share ]; then
          cp -r ${appimageContents}/share/* "$out/share/"
        fi

        # Install the real desktop entries from the extracted AppImage.
        # NOTE: the root-level "LLM Wiki.desktop" in the extract is a
        # symlink to usr/share/applications/...; the real files live in
        # ${appimageContents}/usr/share/applications/ (depth 3).
        if [ -d ${appimageContents}/usr/share/applications ]; then
          mkdir -p "$out/share/applications"
          find ${appimageContents}/usr/share/applications -maxdepth 1 -type f -name '*.desktop' \
            -exec cp {} "$out/share/applications/" \;
        fi

        desktop_file="$(find "$out/share" -type f -name '*.desktop' | head -n 1 || true)"

        if [ -n "$desktop_file" ]; then
          desktop_basename="$(basename "$desktop_file")"

          # 修复：sed -i 在 $out 只读目录下会失败，改用重定向
          sed \
            -e 's|Exec=AppRun|Exec=${pname}|g' \
            -e 's|Exec=AppRun %U|Exec=${pname} %U|g' \
            -e 's|TryExec=AppRun|TryExec=${pname}|g' \
            -e 's|^StartupWMClass=.*$|StartupWMClass=llm-wiki|g' \
            "$desktop_file" > "$desktop_file.tmp" && mv "$desktop_file.tmp" "$desktop_file"

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

        # Install extracted icon
        if [ -f ${icon} ]; then
          install -Dm444 ${icon} "$out/share/icons/hicolor/512x512/apps/${pname}.png"
        fi
      '';

      # Raw upstream AppImage for CI distribution (task-6 takes this path).
      passthru.rawAppImage = src;

      meta = commonMeta;
    };

in
if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64 then
  linuxX64Package
else if stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isAarch64 then
  linuxArm64Package
else
  throw "llm-wiki desktop is only packaged for x86_64-linux and aarch64-linux"
