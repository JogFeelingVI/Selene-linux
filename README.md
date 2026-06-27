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
4. 编译完成后（约 5-8 分钟），点击该次运行记录，拉到页面最下方的 **Artifacts** 区域，点击下载打包好的 **`selene-linux-x64`**（压缩包格式为 `.zip`）。

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
```

---

## 🖥️ 如何开启视频硬件统计悬浮窗 (HUD)

为了方便 Linux 用户监控显卡硬解状态与查看系统时间，本项目内置了一个**全局硬件统计悬浮窗（HUD）**：

*   **开启 / 关闭快捷键**：在视频播放界面中（**窗口模式或全屏模式下均可**），按下键盘上的 **`Left-Shift + Backspace`**（左侧 Shift + 退格键）即可随时调出或隐藏。
*   **悬浮窗展示的信息**：
    *   **系统当前时间**：本地年-月-日及时间，采用防暂停时钟，**即使视频暂停也依然会精确滴答走时**，防止沉浸看剧忘记时间。
    *   **视频物理分辨率**：展示当前视频的真实物理分辨率（如 `1920 x 1080`），便于判断当前画面清晰度。
    *   **当前播放进度**：精确到秒的播放进度与视频总时长。
    *   **渲染模式**：实时展示显卡硬件加速状态（EGL Context - 独占通道）。
    *   **当前播放倍速**：展示如 `1.0x`、`1.5x` 等实时倍速。

---

## 📁 项目特殊目录与脚本说明 (Scripts Directory)

本项目包含一个专属的 **`scripts/`** 目录。该目录搭载了**编译时自动化插桩（Hot-Patching）系统**。它允许你在不污染、不修改原版 Dart 源码的前提下，为软件注入自定义功能。

由于本目录以及工作流文件属于本 Fork 项目专属，**在与官方上游（Upstream）同步时，绝对不会产生任何 Git 代码合并冲突**。

### 目录结构与作用：
* 📂 **`scripts/`**
  * 📄 **`custom_hud_wrapper.dart`**：全局键盘监听的视频信息悬浮窗（HUD）原生 Dart 源码。
    * *如果你想自定义 HUD 界面、修改文本样式、或添加新的播放状态，请直接在此文件中进行修改。你可以在 IDE 中享受完整的 Dart 语法高亮、自动补全和语法检测。*
  * 📄 **`apply_hud_patch.py`**：编译时自动化插桩 Python 脚本。
    * *在 GitHub Actions 编译时，工作流会自动执行此脚本。它采用堆栈括号匹配算法，在 `lib/` 下检索并自动寻找播放器核心文件，在同级目录下生成 `custom_hud_wrapper.dart` 并完成自动组件包裹。*

---

## ⚠️ Linux 平台已知限制与常见问题 (Known Issues)

### 1. 点击“画中画 (PiP)”按钮没有任何画面反应
- **现象**：播放界面中点击“画中画”按钮时，窗口不会弹出，没有任何视觉反馈。终端控制台会抛出异常：`MissingPluginException(No implementation found for method setup on channel pip)`。
- **原因**：上游原项目使用的 `pip` (Picture-in-Picture) 插件仅编写了 Windows、Android 和 iOS 的底层实现，**目前缺失 Linux 平台的原生 C++ 底层代码**。
- **解决方案**：此为原版代码在 Linux 端的适配缺失。在作者重构支持 Linux 画中画前，该功能在 Linux 原生版本下暂时无法使用。

### 2. 在 Wayland 桌面环境下鼠标光标消失或悬停特效丢失
- **现象**：当鼠标划入软件窗口时，光标可能直接隐形消失，或者滑过按钮时没有悬停变色等交互反馈。终端控制台会警告：`Unable to load from the cursor theme` [1]。
- **原因**：部分 Linux 系统在使用 **Wayland** 协议时，对 GTK 鼠标主题的兼容存在局限，导致内嵌 of Flutter 引擎无法正常读取并渲染系统光标。
- **解决方案**：
  - **方法 A：推荐退回到 X11 兼容模式运行**（兼容性极好，能完美恢复光标和动画）：
    ```bash
    GDK_BACKEND=x11 ./selene
    ```
  - **方法 B**：如果坚持使用 Wayland，请在启动时强行指定系统现有的鼠标主题变量（将下文的 `Adwaita` 替换为您系统当前使用的鼠标主题名）：
    ```bash
    XCURSOR_THEME=Adwaita GDK_BACKEND=wayland ./selene
    ```

---

## 🔄 如何同步官方版本？

由于本项目是直接 Fork 自官方仓库，当官方发布新版本或修复 Bug 时，你可以非常方便地同步并自己编译最新版：

1. 打开你 Fork 的这个 GitHub 仓库主页。
2. 点击右上方的 **Sync fork**（同步分叉）按钮，选择 **Update branch**。
3. 同步官方最新代码后，进入 **Actions** 页面，手动运行一次 **Build Selene Linux** 工作流。
4. 下载最新编译出的压缩包，即可完成版本号和代码的完全同步。

---

## 🛠️ 本地手动编译（针对开发者/高级用户）

如果你希望在自己的 Linux 本地机器上进行编译：

### 1. 安装编译依赖
- **Ubuntu / Debian 系**:
  ```bash
  sudo apt update && sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libmpv-dev mpv git
  sudo snap install flutter --classic
  ```
- **Arch Linux / Manjaro**:
  ```bash
  sudo pacman -S clang cmake ninja pkg-config gtk3 xz mpv git flutter
  ```

### 2. 编译步骤
```bash
# 1. 运行本地插桩脚本（按需，可自动完成代码注入）
python3 scripts/apply_hud_patch.py

# 2. 启用 Linux 桌面编译支持并获取依赖
flutter config --enable-linux-desktop
flutter pub get

# 3. 编译 Linux 原生 Release 版本
flutter build linux --release
```
编译产物将保存在 `build/linux/x64/release/bundle/`。
```
