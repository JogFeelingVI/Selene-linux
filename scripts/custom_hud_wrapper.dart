// scripts/custom_hud_wrapper.dart
import 'dart:async'; // 引入异步库以支持 Stream.periodic
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomHudWrapper extends StatefulWidget {
  final Widget child;
  final VideoController? controller; // 允许传入为 null 的控制器

  const CustomHudWrapper({
    super.key,
    required this.child,
    this.controller,
  });

  @override
  State<CustomHudWrapper> createState() => _CustomHudWrapperState();
}

class _CustomHudWrapperState extends State<CustomHudWrapper> {
  // 0: 隐藏, 1: 极简模式, 2: 详细监控面板
  int _hudMode = 0; 
  OverlayEntry? _overlayEntry; // 全局悬浮图层入口

  // 用于拖拽的坐标偏置量
  double _xOffset = 20.0;
  double _yOffset = 40.0;

  // 鼠标悬停透明度控制
  double _hudOpacity = 0.75;

  @override
  void initState() {
    super.initState();
    // 注册全局键盘监听器
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    // 页面销毁时，注销监听器并强制移除悬浮图层，防止内存泄漏
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _hideHud();
    super.dispose();
  }

  // 切换显示状态（循环多档模式）
  void _cycleHudMode() {
    setState(() {
      _hudMode = (_hudMode + 1) % 3;
    });
    if (_hudMode > 0) {
      _showHud();
    } else {
      _hideHud();
    }
  }

  // 格式化视频进度时长 (00:00:00)
  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  // 格式化系统本地时间 (YYYY-MM-DD HH:mm:ss)
  String _formatSystemTime() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return "$year-$month-$day $hour:$minute:$second";
  }

  // 在应用最顶层创建并挂载悬浮图层
  void _showHud() {
    _overlayEntry?.remove(); // 挂载前先清理旧图层，防止重复堆叠

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final player = widget.controller?.player;
        if (player == null) return const SizedBox.shrink();

        return Positioned(
          top: _yOffset,
          left: _xOffset,
          child: Material(
            type: MaterialType.transparency, // 必须包裹 Material
            child: GestureDetector(
              // 1. 拖拽支持：通过累加偏移量并手动标记图层重绘实现平滑拖动
              onPanUpdate: (details) {
                _xOffset += details.delta.dx;
                _yOffset += details.delta.dy;
                _overlayEntry?.markNeedsBuild();
              },
              child: MouseRegion(
                // 2. 悬停反馈：鼠标移入调高透明度，移出调低以减少视觉遮挡
                onEnter: (_) {
                  _hudOpacity = 1.0;
                  _overlayEntry?.markNeedsBuild();
                },
                onExit: (_) {
                  _hudOpacity = 0.75;
                  _overlayEntry?.markNeedsBuild();
                },
                child: Opacity(
                  opacity: _hudOpacity,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black54,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: StreamBuilder(
                      // 局部刷新机制
                      stream: Stream.periodic(const Duration(milliseconds: 1000)),
                      builder: (context, snapshot) {
                        final currentPos = player.state.position;
                        final totalDur = player.state.duration;
                        final isPlaying = player.state.playing;
                        final isBuffering = player.state.buffering;
                        final bufferDur = player.state.buffer;

                        if (_hudMode == 1) {
                          return _buildMinimalHud(player, currentPos, totalDur, isPlaying);
                        } else {
                          return _buildAdvancedHud(player, currentPos, totalDur, isPlaying, isBuffering, bufferDur);
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    // 挂载到全局顶层 Overlay 画布中
    try {
      Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    } catch (e) {
      // 兼容性降级
      Overlay.of(context).insert(_overlayEntry!);
    }
  }

  // 极简模式 HUD UI
  Widget _buildMinimalHud(dynamic player, Duration currentPos, Duration totalDur, bool isPlaying) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.video_settings, color: Colors.cyanAccent, size: 14),
        const SizedBox(width: 6),
        Text(
          "${player.state.width ?? 0}x${player.state.height ?? 0}",
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 12),
        Icon(isPlaying ? Icons.play_arrow : Icons.pause, color: Colors.greenAccent, size: 12),
        const SizedBox(width: 4),
        Text(
          "${_formatDuration(currentPos)} / ${_formatDuration(totalDur)}",
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ],
    );
  }

  // 构建单个速度按钮组件
  Widget _buildSpeedButton(dynamic player, double rate, String label) {
    // 允许微小的浮点数偏差
    final isCurrent = (player.state.rate - rate).abs() < 0.05;
    return GestureDetector(
      onTap: () async {
        await player.setRate(rate);
        _overlayEntry?.markNeedsBuild(); // 触发即时更新 UI 上的选中状态
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: isCurrent ? Colors.cyanAccent.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isCurrent ? Colors.cyanAccent : Colors.white24,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isCurrent ? Colors.cyanAccent : Colors.white70,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 详细监控面板 UI
  Widget _buildAdvancedHud(
    dynamic player,
    Duration currentPos,
    Duration totalDur,
    bool isPlaying,
    bool isBuffering,
    Duration bufferDur,
  ) {
    // 轨道信息安全检测：尝试从 media_kit 获取当前音轨和字幕轨语言
    String audioTrackInfo = "未知";
    String subtitleTrackInfo = "无";
    try {
      final audioTrack = player.state.track.audio;
      final subTrack = player.state.track.subtitle;
      audioTrackInfo = audioTrack.title ?? audioTrack.language ?? "未知";
      subtitleTrackInfo = subTrack.title ?? subTrack.language ?? "无";
    } catch (_) {
      // 防止某些低版本或特殊源由于属性不存在导致崩溃
    }

    return SizedBox(
      width: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 简易控制区与关闭按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "📊 视频与系统状态面板",
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => player.playOrPause(),
                    child: Icon(
                      isPlaying ? Icons.pause_circle : Icons.play_circle,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      _hideHud();
                    },
                    child: const Icon(
                      Icons.cancel,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 12, thickness: 1),
          
          // 系统状态行
          _buildInfoRow("系统时间", _formatSystemTime(), Colors.yellowAccent),
          _buildInfoRow("渲染模式", "硬件加速 (EGL Context - 独占通道)", Colors.greenAccent),
          const SizedBox(height: 4),

          // 媒体状态行
          _buildInfoRow("分辨率", "${player.state.width ?? 0} x ${player.state.height ?? 0}", Colors.white),
          _buildInfoRow("当前进度", "${_formatDuration(currentPos)} / ${_formatDuration(totalDur)}", Colors.white),
          
          // 3. 速度控制行：展示当前速率并提供 1.0x, 1.5x, 2.0x 快捷选项
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "播放速率:",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                Row(
                  children: [
                    Text(
                      "${player.state.rate.toStringAsFixed(1)}x",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    _buildSpeedButton(player, 1.0, "1.0x"),
                    const SizedBox(width: 4),
                    _buildSpeedButton(player, 1.5, "1.5x"),
                    const SizedBox(width: 4),
                    _buildSpeedButton(player, 2.0, "2.0x"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // 网络与音轨状态行
          _buildInfoRow(
            "网络缓冲",
            isBuffering ? "加载中..." : "已缓冲 ${_formatDuration(bufferDur)}",
            isBuffering ? Colors.orangeAccent : Colors.white70,
          ),
          _buildInfoRow("当前音轨", audioTrackInfo, Colors.white70),
          _buildInfoRow("当前字幕", subtitleTrackInfo, Colors.white70),
          const Divider(color: Colors.white12, height: 12, thickness: 1),

          // 提示行
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "💡 Shift+1/2 可快捷调速",
                style: TextStyle(color: Colors.white38, fontSize: 9),
              ),
              Text(
                "Shift+Backspace 切换",
                style: TextStyle(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 辅助构建排版行
  Widget _buildInfoRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(color: valueColor, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // 销毁和隐藏悬浮图层
  void _hideHud() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _hudMode = 0;
      });
    }
  }

  // 全局按键捕获
  bool _handleGlobalKeyEvent(KeyEvent event) {
    final player = widget.controller?.player;
    if (player == null) return false;

    if (event is KeyDownEvent) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final isShiftPressed = keys.contains(LogicalKeyboardKey.shiftLeft) || 
                             keys.contains(LogicalKeyboardKey.shiftRight);
                             
      // Shift + Backspace: 切换 HUD 模式
      if (isShiftPressed && event.logicalKey == LogicalKeyboardKey.backspace) {
        _cycleHudMode();
        return true;
      }

      // 4. 新增快捷键：Shift + 2 -> 快速切换至 2.0x 速率
      if (isShiftPressed && event.logicalKey == LogicalKeyboardKey.digit2) {
        player.setRate(2.0);
        _overlayEntry?.markNeedsBuild(); // 手动标记重绘，使 UI 获得即时反馈
        return true;
      }

      // 5. 新增快捷键：Shift + 1 -> 恢复 1.0x 速率
      if (isShiftPressed && event.logicalKey == LogicalKeyboardKey.digit1) {
        player.setRate(1.0);
        _overlayEntry?.markNeedsBuild(); // 手动标记重绘，使 UI 获得即时反馈
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // 维持非侵入式，直接原样返回播放器组件
    return widget.child; 
  }
}
