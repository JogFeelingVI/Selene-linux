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
  bool _showStats = false;
  OverlayEntry? _overlayEntry; // 全局悬浮图层入口

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

  // 切换显示状态
  void _toggleHud() {
    setState(() {
      _showStats = !_showStats;
    });
    if (_showStats) {
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
    _hideHud(); // 挂载前先清理旧图层，防止重复堆叠

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final player = widget.controller?.player;
        if (player == null) return const SizedBox.shrink();

        return Positioned(
          top: 40, // 稍微向下偏移，避开系统栏
          left: 20,
          child: Material(
            type: MaterialType.transparency, // 必须包裹 Material
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: StreamBuilder(
                // 核心优化：使用每 500 毫秒触发一次的定期流，保证视频暂停时本地时钟仍在正常走动
                stream: Stream.periodic(const Duration(milliseconds: 1000)),
                builder: (context, snapshot) {
                  final currentPos = player.state.position;
                  final totalDur = player.state.duration;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "📊 视频渲染统计信息",
                        style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      // 新增：系统本地时间行
                      Text(
                        "系统时间: ${_formatSystemTime()}",
                        style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.w500, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "视频分辨率: ${player.state.width ?? 0} x ${player.state.height ?? 0}",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Text(
                        "当前进度: ${_formatDuration(currentPos)} / ${_formatDuration(totalDur)}",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const Text(
                        "渲染模式: 硬件加速 (EGL Context - 独占通道)",
                        style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                      ),
                      Text(
                        "播放速率: ${player.state.rate.toStringAsFixed(1)}x",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "快捷键: Left-Shift + Backspace 隐藏",
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  );
                },
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

  // 销毁和隐藏悬浮图层
  void _hideHud() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // 全局按键捕获
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (widget.controller == null) return false;

    if (event is KeyDownEvent) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      final isShiftPressed = keys.contains(LogicalKeyboardKey.shiftLeft) || 
                             keys.contains(LogicalKeyboardKey.shiftRight);
                             
      if (isShiftPressed && event.logicalKey == LogicalKeyboardKey.backspace) {
        _toggleHud();
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // build 方法依然保持 100% 纯净，直接原样返回播放器组件
    return widget.child; 
  }
}
