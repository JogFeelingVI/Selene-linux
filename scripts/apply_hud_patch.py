# scripts/apply_hud_patch.py
import os
import re

# HUD 的完整 Dart 代码
hud_code = """import 'package:flutter/material.dart';
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.controller.player;

    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          if (isShiftPressed && event.logicalKey == LogicalKeyboardKey.backspace) {
            setState(() {
              _showStats = !_showStats;
            });
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          widget.child,
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
      ),
    );
  }
}
"""

def main():
    # 自动定位播放器 Dart 文件
    target_file = None
    for root, dirs, files in os.walk('lib'):
        for file in files:
            if file.endswith('.dart'):
                path = os.path.join(root, file)
                try:
                    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        if '=== PlayerScreen' in content or 'Video(controller:' in content:
                            target_file = path
                            break
                except Exception:
                    pass
        if target_file:
            break

    if target_file:
        target_dir = os.path.dirname(target_file)
        print(f"找到目标播放器文件: {target_file}")
        
        # 1. 写入 custom_hud_wrapper.dart 到同级目录
        hud_path = os.path.join(target_dir, 'custom_hud_wrapper.dart')
        with open(hud_path, 'w', encoding='utf-8') as f:
            f.write(hud_code)
        print(f"已自动创建组件: {hud_path}")
            
        # 2. 读取并修改目标播放器文件
        with open(target_file, 'r', encoding='utf-8') as f:
            code = f.read()
        
        # 检查是否已经注入过导入声明，避免重复注入
        if "import 'custom_hud_wrapper.dart';" not in code:
            code = "import 'custom_hud_wrapper.dart';\n" + code
        
        # 使用正则替换 Video(controller: xxx) 为 CustomHudWrapper 包裹
        new_code = re.sub(
            r'Video\s*\(\s*controller\s*:\s*([a-zA-Z0-9_\.]+)\s*\)', 
            r'CustomHudWrapper(controller: \1, child: Video(controller: \1))', 
            code
        )
        
        with open(target_file, 'w', encoding='utf-8') as f:
            f.write(new_code)
        print("代码热补丁注入成功！")
    else:
        print("错误: 未能在项目中找到对应的播放器 Dart 文件！")

if __name__ == '__main__':
    main()
