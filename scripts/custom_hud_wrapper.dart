// scripts/custom_hud_wrapper.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomHudWrapper extends StatefulWidget {
  final Widget child;
  final VideoController? controller; // 核心修正：允许传入为 null 的控制器

  const CustomHudWrapper({
    super.key,
    required this.child,
    this.controller, // 允许为 null 的构造函数
  });

  @override
  State<CustomHudWrapper> createState() => _CustomHudWrapperState();
}

class _CustomHudWrapperState extends State<CustomHudWrapper> {
  bool _showStats = false;

  @override
  void initState() {
    super.initState();
    // 注册全局键盘监听器
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  @override
  void dispose() {
    // 注销监听器，防止内存泄漏
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  // 全局按键捕获逻辑
  bool _handleGlobalKeyEvent(KeyEvent event) {
    // 如果控制器尚未初始化（为 null），不处理键盘事件
    if (widget.controller == null) return false;

    if (event is KeyDownEvent) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      
      // 同时兼容左 Shift 和右 Shift
      final isShiftPressed = keys.contains(LogicalKeyboardKey.shiftLeft) || 
                             keys.contains(LogicalKeyboardKey.shiftRight);
                             
      if (isShiftPressed && event.logicalKey == LogicalKeyboardKey.backspace) {
        setState(() {
          _showStats = !_showStats; // 切换显示状态
        });
        return true; // 消费此按键事件
      }
    }
    return false;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    // 使用可空调用符号安全获取 player
    final player = widget.controller?.player;

    return Stack(
      children: [
        // 渲染原有的视频播放器
        widget.child,

        // 只有在开启显示，且 player 实例确实不为 null 时，才渲染 HUD
        if (_showStats && player != null)
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: StreamBuilder(
                stream: player.stream.position,
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
      ],
    );
  }
}
