# scripts/apply_hud_patch.py
import os
import re

def main():
    # 定义源 HUD 模板文件的路径
    source_hud_path = 'scripts/custom_hud_wrapper.dart'
    
    if not os.path.exists(source_hud_path):
        print(f"错误: 未找到源 HUD 模板文件 {source_hud_path}！")
        return

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
        
        # 1. 直接读取独立的 custom_hud_wrapper.dart 源码内容
        with open(source_hud_path, 'r', encoding='utf-8') as f:
            hud_code = f.read()

        # 2. 将其写入到目标播放器的同级目录下
        hud_path = os.path.join(target_dir, 'custom_hud_wrapper.dart')
        with open(hud_path, 'w', encoding='utf-8') as f:
            f.write(hud_code)
        print(f"已自动创建组件: {hud_path}")
            
        # 3. 读取并修改目标播放器文件
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
