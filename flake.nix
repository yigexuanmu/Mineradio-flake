{
  description = "Mineradio - 沉浸式音乐播放器 (Electron, Nix flake)";

  inputs = {
    nixpkgs.url = "nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      electron = pkgs.electron_42;

      # 应用源码来自上游官方仓库 XxHuberrr/Mineradio (本 flake 仓库只放 nix 文件)
      mineradioSrc = pkgs.fetchFromGitHub {
        owner = "XxHuberrr";
        repo = "Mineradio";
        rev = "6b130103f759e5dcd1e133700071c8216b8fa5a6";
        hash = "sha256-FS82IdKHiUxLX3Y3Azso72+stRiMDsFPxt1gEfDd1WI=";
      };

      # 运行时依赖 (productionDependencies: gsap / mpg123-decoder / NeteaseCloudMusicApi)
      # devDependencies (electron / electron-builder / rcedit) 不安装, 由 nixpkgs 提供 electron。
      # 构建沙箱 (nixbld) 无外网, 无法在 derivation 内 `npm ci`, 故预构建为 tarball 并作为本仓库的
      # GitHub Release 资产提供, 由 fetchTarball 引入。重新生成:
      #   npm ci --omit=dev && tar -czf node_modules.tar.gz -C node_modules . && nix hash file node_modules.tar.gz
      # 再上传到 releases/tag/node_modules-v1.1.1 并替换下方 sha256。
      nodeDeps = builtins.fetchTarball {
        url = "https://github.com/yigexuanmu/Mineradio-flake/releases/download/node_modules-v1.1.1/node_modules.tar.gz";
        sha256 = "0py7pydzy9ys25apyppgh38gmyk07za95xprv60v3kbrrnmc3inw";
      };
    in
    {
      packages.${system} = {
        mineradio = pkgs.stdenv.mkDerivation {
          pname = "mineradio";
          version = "1.1.1";

          src = mineradioSrc;

          nativeBuildInputs = [
            pkgs.copyDesktopItems
          ];

          buildInputs = [
            electron
          ];

          dontBuild = true;

          installPhase = ''
            runHook preInstall

            app=$out/share/mineradio
            mkdir -p "$app"

            # 复制 Electron 运行所需的 app 文件
            cp -r "$src/desktop" "$src/public" "$src/build" "$src/server.js" "$src/dj-analyzer.js" "$src/package.json" "$app/"

            # 复制运行时依赖 node_modules
            cp -r ${nodeDeps} "$app/node_modules"

            # 复制进来的文件来自只读 store, 先放开写权限
            chmod -R u+w "$app"

            # 修正 Windows 专属的 ANGLE 后端 (d3d11 在 Linux 不可用)
            sed -i "s|\['use-angle', 'd3d11'\]|['use-angle', 'gl']|" "$app/desktop/main.js"

            # 图标
            mkdir -p "$out/share/icons/hicolor/512x512/apps"
            cp "$src/build/icon.png" "$out/share/icons/hicolor/512x512/apps/mineradio.png"

            # 启动器: 用 nixpkgs 的 electron 跑本 app 目录
            # server.js 会被 desktop/main.js require 起来, 监听 127.0.0.1:PORT
            # 注意: 这里用脚本而非 makeWrapper --set, 否则 $HOME 会在构建期被写死
            mkdir -p "$out/bin"
            cat > "$out/bin/mineradio" <<EOF
#! ${pkgs.runtimeShell}
export MINERADIO_BEAT_CACHE_DIR="\$HOME/.cache/mineradio/beatmaps"
export ELECTRON_APP_NAME="Mineradio"
exec ${pkgs.lib.getExe electron} $out/share/mineradio "\$@"
EOF
            chmod +x "$out/bin/mineradio"

            runHook postInstall
          '';

          desktopItems = [
            (pkgs.makeDesktopItem {
              name = "mineradio";
              exec = "mineradio";
              icon = "mineradio";
              desktopName = "Mineradio";
              comment = "沉浸式音乐播放器，融合天气电台、歌词舞台、粒子视觉和 3D 歌单架";
              categories = [ "AudioVideo" "Audio" "Music" "Player" ];
              terminal = false;
            })
          ];

          meta = with pkgs.lib; {
            homepage = "https://github.com/XxHuberrr/Mineradio";
            description = "沉浸式音乐播放器 (Electron)";
            license = licenses.gpl3Only;
            mainProgram = "mineradio";
            platforms = electron.meta.platforms;
          };
        };

        default = self.packages.${system}.mineradio;
      };
    };
}
