# Mineradio

**Mineradio** 是一款沉浸式音乐播放器（Electron 封装），融合天气电台、搜索播放、歌词舞台、粒子视觉和 3D 歌单架，并接入网易云音乐 / QQ 音乐的账号、搜索、歌单、播客等体验。

本仓库 [`yigexuanmu/Mineradio-flake`](https://github.com/yigexuanmu/Mineradio-flake) 是 Mineradio 的 **Nix flake 打包**，让它在 NixOS（及任何支持 Nix flakes 的 Linux）上可一条命令安装运行。

## 这个 flake 里有什么

- **应用源码**：来自上游官方仓库 [`XxHuberrr/Mineradio`](https://github.com/XxHuberrr/Mineradio)，本仓库不包含应用代码。
- **运行时依赖**：`gsap` / `mpg123-decoder`（WASM 音频解码）/ `NeteaseCloudMusicApi`，已预构建为 GitHub Release 资产，由 `fetchTarball` 引入。
- **Electron**：来自 nixpkgs（`electron_42`），不进 node_modules。
- **产出**：`packages.x86_64-linux.default` = `mineradio`，含启动脚本、`.desktop` 与图标。

## 特性 / 说明

- 本地起一个 HTTP 服务（默认 `127.0.0.1:3000`）提供搜索、歌词、天气电台等 API。
- 登录态、歌单、自定义封面等存于 Electron `userData`，不写入只读 store。
- 已把 Windows 专属的 `use-angle d3d11` 改为 `gl`，并开启 GPU 加速相关开关。

---

# NixOS 安装教程

本教程介绍在 NixOS 上通过本 flake 安装 Mineradio 的几种方式：

1. 直接 `nix run` / `nix build` 试用
2. 把 flake 作为 input 引入，用 `systemPackages` 装到系统
3. 用 Home Manager 的 `home.packages` 装到用户

> 本 flake 的运行时依赖（`gsap` / `mpg123-decoder` / `NeteaseCloudMusicApi`）已预构建为 GitHub Release 资产，`electron` 来自 nixpkgs，构建时**无需联网**（`nixpkgs` / 上游源码 / 依赖资产均从 GitHub 拉取）。

---

## 0. 前置条件

- NixOS 且已启用 flakes（`nix.settings.experimental-features = [ "nix-command" "flakes" ];`）
- 架构 `x86_64-linux`（flake 目前只产出该平台）
- 运行需联网（拉取音乐/歌词），以及图形会话（X11 或 Wayland）

---

## 1. 快速试用（无需修改配置）

直接用 flake 地址运行：

```bash
nix run github:yigexuanmu/Mineradio-flake
```

或先构建再运行：

```bash
nix build github:yigexuanmu/Mineradio-flake
./result/bin/mineradio
```

这会在当前目录生成 `result/`，其中包含 `bin/mineradio` 与桌面入口。

---

## 2. 作为 flake input 引入（推荐）

在你的系统 flake（通常是 `/etc/nixos/flake.nix`）中把本 flake 加为 input，并用 `environment.systemPackages` 安装。

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    mineradio-flake = {
      url = "github:yigexuanmu/Mineradio-flake";
      # 复用你的 nixpkgs，避免引入第二份 nixpkgs 导致 electron 版本不一致
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, mineradio-flake, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations."<你的主机名>" = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ({ config, pkgs, ... }: {
            environment.systemPackages = [
              mineradio-flake.packages.${system}.default
            ];
          })
        ];
      };
    };
}
```

应用配置：

```bash
sudo nixos-rebuild switch
```

之后即可在终端执行 `mineradio`，并在桌面环境的应用菜单里看到 **Mineradio**（`.desktop` 会被安装到 `share/applications/`）。

---

## 3. 用 Home Manager 安装

如果你用 Home Manager 管理用户环境，把 flake 加为 Home Manager 的 input，再用 `home.packages`。

Home Manager 作为 NixOS 模块时的示例（`/etc/nixos/flake.nix`）：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mineradio-flake = {
      url = "github:yigexuanmu/Mineradio-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, mineradio-flake, ... }:
    let
      system = "x86_64-linux";
      username = "<你的用户名>";
    in
    {
      nixosConfigurations."<你的主机名>" = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          home-manager.nixosModules.home-manager
          {
            home-manager.useUserPackages = true;
            home-manager.users.${username} = { pkgs, ... }: {
              home.packages = [
                mineradio-flake.packages.${system}.default
              ];
            };
          }
        ];
      };
    };
}
```

若 Home Manager 是**独立 flake**（`home-manager switch --flake`），则在你的 Home Manager `flake.nix` 的 `inputs` 里加同样的 `mineradio-flake`，并在 `outputs` 的 user 配置里写 `home.packages = [ mineradio-flake.packages.${system}.default ];`。

应用：

```bash
home-manager switch   # 或 sudo nixos-rebuild switch（随你的接入方式）
```

---

## 4. 运行与验证

```bash
mineradio
```

启动后本地会起一个 HTTP 服务（默认 `127.0.0.1:3000`），可提供 API：

```bash
curl http://127.0.0.1:3000/api/app/version
# => {"name":"mineradio","version":"1.1.1",...}
```

歌词舞台、粒子视觉、天气电台、网易云/QQ 登录等需在图形会话下使用。

---

## 5. 注意事项

### GPU 加速
flake 已开启 GPU 相关 Chromium 开关（`ignore-gpu-blocklist`、`enable-gpu-rasterization`、`force_high_performance_gpu`，并把 Windows 专属的 `use-angle d3d11` 改为 `gl`）。

- **X11 会话**：通常直接硬加速。
- **Wayland 会话**：若启动日志出现 `ozone-platform=wayland is not compatible with Vulkan`，建议强制 X11：
  ```bash
  mineradio --ozone-platform=x11
  ```
  或写个 wrapper / `.desktop` 加上该参数。

### 缓存目录
节奏分析缓存默认写到 `~/.cache/mineradio/beatmaps`（由启动脚本设置 `MINERADIO_BEAT_CACHE_DIR`）。如需改路径，在启动前 `export MINERADIO_BEAT_CACHE_DIR=/自定义/路径`。

### 登录态 / 用户数据
Cookie、歌单、自定义封面等存于 Electron 的 `userData`（一般在 `~/.config/Mineradio` 或 `~/.config/Electron`），不会写入软件目录，符合 Nix 只读 store 的约定。

### 升级依赖
运行时依赖变更后，在本仓库重新生成并上传 Release 资产：

```bash
npm ci --omit=dev
tar -czf node_modules.tar.gz -C node_modules .
nix hash file node_modules.tar.gz   # 替换 flake.nix 里 nodeDeps 的 sha256
```

再覆盖 `releases/tag/node_modules-v1.1.1` 的 `node_modules.tar.gz`。应用源码来自上游 `XxHuberrr/Mineradio`，版本跟随其 `main`。
