# Selene - Linux 原生编译版 (Fork)

本项目分叉 (Fork) 自官方源码库 [MoonTechLab/Selene-Source](https://github.com/MoonTechLab/Selene-Source)。

---

## 📌 项目背景与目的

官方目前未直接提供 Linux 平台的预编译客户端。虽然可以通过 Wine 运行 Windows 客户端，但由于 Wine 的视频解码翻译限制，播放器内核（`libmpv`）往往会降级为 **CPU 软件解码**，并且整套 Flutter UI 也可能退化为 **CPU 软件渲染 (SwiftShader)**，导致 CPU 占用率极高、电脑发热严重。

为了解决这一问题，本项目**专门为 Linux 用户提供原生编译支持**：
- **完全原生运行**：直接在 Linux 系统下构建，免去 Wine 环境的额外损耗。
- **原生硬件解码**：原生链接 Linux 本地的 `libmpv.so`，完美调用系统的 **VA-API / NVDEC** 硬件解码，显卡直接参与视频渲染，大幅降低 CPU 占用与温度。

---

## 🚀 如何获取原生 Linux 客户端？

本项目配置了 GitHub Actions 自动化编译工作流，**你无需在本地安装任何复杂的 Flutter 开发环境**，可以直接下载云端编译好的“绿色版”程序：

1. 点击本项目顶部的 **Actions** 标签页。
2. 在左侧菜单中选择 **Build Selene Linux** 工作流。
3. 点击右侧的 **Run workflow** 手动触发编译（或者直接查看历史已完成的绿色对勾运行记录）。
4. 编译完成后（约 5-8 分钟），点击该次运行记录，拉到页面最下方的 **Artifacts** 区域，下载打包好的 **`selene-linux-x64`**（压缩包格式为 `.zip`）。

---

## ⚙️ 如何运行

下载 `selene-linux-x64.zip` 后，在你的 Linux 终端中运行以下命令解压并启动：

```bash
# 1. 新建一个文件夹并将压缩包解压进去（避免文件散落）
mkdir selene-linux
unzip selene-linux-x64.zip -d selene-linux
cd selene-linux

# 2. 赋予可执行权限
chmod +x selene

# 3. 运行原生客户端
./selene
