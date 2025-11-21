#!/bin/bash

# --- 变量设置 ---
FILENAME="snake_main.c"
OUTPUT_NAME="./snake_game"
NCURSES_FLAG="-lncurses"  # 链接 ncurses 库的标志

echo "---------------------------------------"
echo "C语言贪吃蛇 自动编译运行脚本 (Linux/macOS)"
echo "---------------------------------------"
echo

# 检查源文件是否存在
if [ ! -f "$FILENAME" ]; then
    echo "错误：源文件 $FILENAME 不存在!"
    exit 1
fi

# 1. 编译阶段 (链接 ncurses 库)
echo "[1/2] 正在编译 $FILENAME 并链接 $NCURSES_FLAG ..."
# 使用 GCC 编译，并添加 ncurses 链接标志
gcc "$FILENAME" -o "$OUTPUT_NAME" "$NCURSES_FLAG"

# 检查上一个命令 (gcc) 的退出状态
if [ $? -ne 0 ]; then
    echo
    echo "---------------------------------------"
    echo "!!! 编译失败。请确保您已安装 'libncurses5-dev' 或类似开发包 !!!"
    echo "  (错误通常是 'undefined reference' 或文件找不到)"
    echo "---------------------------------------"
    exit 1
fi

echo "[1/2] 编译成功! 生成可执行文件: $OUTPUT_NAME"
echo

# 2. 运行阶段
echo "[2/2] 正在运行游戏..."
echo "======================================="

# 运行程序
"$OUTPUT_NAME"

echo "======================================="
echo "脚本执行完毕。"
echo "---------------------------------------"