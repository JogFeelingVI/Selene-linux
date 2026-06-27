import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

class CustomHudWrapper extends StatefulWidget {
  final Widget child;
  final VideoController controller;

  const CustomHudWrapper({
    super.key,
    required this.child,
    required this.controller,
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

  // 全局按键捕获与调试诊断逻辑
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      
      // 极其稳健的 Shift 判定：物理状态判断 + 键集扫描判定
      final isShiftPressed = HardwareKeyboard.instance.isShiftPressed ||
                             keys.contains(LogicalKeyboardKey.shiftLeft) || 
                             keys.contains(LogicalKeyboardKey.shiftRight);
                             
      final isBackspace = event.logicalKey == LogicalKeyboardKey.backspace;
      final isF12 = event.logicalKey == LogicalKeyboardKey.f12;

      // 实时终端调试打印（启动时用 ./selene 即可在终端实时观测）
      print("【HUD 调试】按下按键: ${event.logicalKey.debugName} | Shift状态: $isShiftPressed | 是否为 F12: $isF12");

      // 触发条件：[Shift + Backspace] 或者 单独按下 [F12]
      if ((isShiftPressed && isBackspace) || isF12) {
        setState(() {
          _showStats = !_showStats; // 切换显示状态
        });
        print("【HUD 调试】成功触发 HUD 状态切换！当前显示状态: $_showStats");
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
    final player = widget.controller.player;

    return Stack(
      children: [
        // 渲染原有的视频播放器
        widget.child,

        // 渲染 HUD 信息
        if (_showStats)
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
                        "快捷键: Left-Shift+Backspace 或 F12 隐藏",
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
