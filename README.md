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

## 2. 在 flake.nix 中引入

在系统 flake（`/etc/nixos/flake.nix`）的 `inputs` 里加上本 flake：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mineradio.url = "github:yigexuanmu/Mineradio-flake";
  };

  outputs = { self, nixpkgs, mineradio, ... } @ inputs: {
    # ...
  };
}
```

> 提示：如果想复用你自己的 nixpkgs（避免引入第二份导致 `electron` 版本不一致），可加一行 `inputs.nixpkgs.follows = "nixpkgs";`：
>
> ```nix
> mineradio = {
>   url = "github:yigexuanmu/Mineradio-flake";
>   inputs.nixpkgs.follows = "nixpkgs";
> };
> ```

---

## 3. 安装到系统

**NixOS（`environment.systemPackages`）**

```nix
environment.systemPackages = [
  inputs.mineradio.packages.x86_64-linux.default
];
```

应用：`sudo nixos-rebuild switch`。之后终端执行 `mineradio`，应用菜单里也会出现 **Mineradio**（`.desktop` 已安装）。

**Home Manager（`home.packages`）**

```nix
home.packages = [
  inputs.mineradio.packages.x86_64-linux.default
];
```

应用：`home-manager switch`（或随你的接入方式 `sudo nixos-rebuild switch`）。

> Home Manager 作为独立 flake 时，同样在它的 `inputs` 里加 `mineradio.url = "github:yigexuanmu/Mineradio-flake"`，再在用户配置里写上面的 `home.packages` 即可。

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
