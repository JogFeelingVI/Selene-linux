# scripts/apply_hud_patch.py
import os
import re
import sys

def wrap_video_widget(code):
    """
    使用括号匹配算法，精准提取并包裹 Video(...) 组件。
    支持任意多行、多参数、以及尾随逗号。
    """
    pattern = re.compile(r'\bVideo\s*\(')
    pos = 0
    replacements_count = 0
    
    while True:
        match = pattern.search(code, pos)
        if not match:
            break
            
        start_idx = match.start()
        open_paren_idx = match.end() - 1 # '(' 的位置
        
        # 向后扫描，利用堆栈计数寻找配对的右括号 ')'
        paren_count = 1
        end_idx = -1
        for i in range(open_paren_idx + 1, len(code)):
            if code[i] == '(':
                paren_count += 1
            elif code[i] == ')':
                paren_count -= 1
                if paren_count == 0:
                    end_idx = i
                    break
        
        # 如果括号未闭合，说明格式异常，跳过
        if end_idx == -1:
            pos = open_paren_idx + 1
            continue
            
        # 完整剥离出 Video(...) 代码块
        video_block = code[start_idx : end_idx + 1]
        
        # 从该代码块中提取控制器变量名（匹配数字、字母、下划线及点号如 widget.controller）
        controller_match = re.search(r'controller\s*:\s*([a-zA-Z0-9_\.]+)', video_block)
        if not controller_match:
            pos = end_idx + 1
            continue
            
        controller_var = controller_match.group(1)
        
        # 生成包裹后的新代码块
        wrapped_block = f"CustomHudWrapper(controller: {controller_var}, child: {video_block})"
        
        # 替换原代码
        code = code[:start_idx] + wrapped_block + code[end_idx + 1:]
        
        # 计数并更新扫描起始位置
        replacements_count += 1
        pos = start_idx + len(wrapped_block)
        
    return code, replacements_count

def main():
    source_hud_path = 'scripts/custom_hud_wrapper.dart'
    
    if not os.path.exists(source_hud_path):
        print(f"错误: 未找到源 HUD 模板文件 {source_hud_path}！")
        sys.exit(1)

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
        
        # 1. 读取独立的 custom_hud_wrapper.dart 源码内容
        with open(source_hud_path, 'r', encoding='utf-8') as f:
            hud_code = f.read()

        # 2. 将其写入到目标播放器的同级目录下
        hud_path = os.path.join(target_dir, 'custom_hud_wrapper.dart')
        with open(hud_path, 'w', encoding='utf-8') as f:
            f.write(hud_code)
        print(f"已自动创建组件: {hud_path}")
            
        # 3. 读取目标播放器文件
        with open(target_file, 'r', encoding='utf-8') as f:
            code = f.read()
        
        # 4. 执行堆栈算法进行安全包裹
        new_code, num_subs = wrap_video_widget(code)
        
        if num_subs > 0:
            # 检查并注入导入声明
            if "import 'custom_hud_wrapper.dart';" not in new_code:
                new_code = "import 'custom_hud_wrapper.dart';\n" + new_code
            
            with open(target_file, 'w', encoding='utf-8') as f:
                f.write(new_code)
            print(f"【成功】代码热补丁注入成功！成功包装了 {num_subs} 个 Video 播放器组件。")
        else:
            print("【严重错误】虽然找到了播放器文件，但未能成功定位并包装 Video(controller: ...) 组件！")
            sys.exit(1) # 强行终止编译，让 GitHub Action 报错变红
    else:
        print("【错误】未能在项目中找到对应的播放器 Dart 文件！")
        sys.exit(1)

if __name__ == '__main__':
    main()
