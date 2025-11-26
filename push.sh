#!/bin/bash

# ============================================
# Git 智能选择性提交推送脚本 (push.sh)
# 用法:
#   ./push.sh [提交信息]           # 选择性提交模式
#   ./push.sh -a [提交信息]        # 提交所有更改
#   ./push.sh -s [提交信息]        # 只提交已暂存的文件
# ============================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 解析参数
MODE="selective"  # 默认为选择性模式
COMMIT_MSG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--all)
            MODE="all"
            shift
            ;;
        -s|--staged)
            MODE="staged"
            shift
            ;;
        -h|--help)
            echo "用法: $0 [选项] [提交信息]"
            echo ""
            echo "选项:"
            echo "  -a, --all      提交所有更改(包括新文件)"
            echo "  -s, --staged   只提交已暂存的文件"
            echo "  -h, --help     显示此帮助信息"
            echo ""
            echo "默认模式: 选择性提交(显示文件列表供选择)"
            exit 0
            ;;
        *)
            COMMIT_MSG="$*"
            break
            ;;
    esac
done

# 1. 检查是否有更改(包括新文件)
# 使用 git status --porcelain 可以检测到所有类型的改动
HAS_STAGED=$(git diff --cached --quiet && echo "false" || echo "true")
HAS_UNSTAGED=$(git status --porcelain | grep -q '^ M\|^M \|^MM\|^ D\|^??' && echo "true" || echo "false")

if [ "$HAS_STAGED" = "false" ] && [ "$HAS_UNSTAGED" = "false" ]; then
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}✅ 工作区和暂存区都很干净,无需提交。${NC}"
    echo -e "${GREEN}============================================${NC}"
    exit 0
fi

# 2. 根据模式处理文件
case $MODE in
    "all")
        echo -e "${BLUE}🚀 模式: 提交所有更改${NC}"
        git add .
        ;;

    "staged")
        echo -e "${BLUE}🚀 模式: 只提交已暂存的文件${NC}"
        if git diff --cached --quiet; then
            echo -e "${YELLOW}⚠️  暂存区为空,没有可提交的文件。${NC}"
            exit 0
        fi
        ;;

    "selective")
        echo -e "${BLUE}🚀 模式: 选择性提交${NC}"
        echo ""

        # 获取所有更改的文件(包括未跟踪的新文件)
        mapfile -t ALL_FILES < <(git status --porcelain | sed 's/^...//; s/^"//; s/"$//')

        if [ ${#ALL_FILES[@]} -eq 0 ]; then
            echo -e "${GREEN}✅ 没有修改的文件。${NC}"
            exit 0
        fi

        # 显示文件列表
        echo -e "${YELLOW}发现以下修改的文件:${NC}"
        echo ""

        DISPLAY_FILES=()
        for i in "${!ALL_FILES[@]}"; do
            FILE="${ALL_FILES[$i]}"
            # 跳过空行
            [ -z "$FILE" ] && continue

            DISPLAY_FILES+=("$FILE")
        done

        for i in "${!DISPLAY_FILES[@]}"; do
            FILE="${DISPLAY_FILES[$i]}"
            STATUS=$(git status --porcelain | grep -F "$FILE" | awk '{print $1}')

            case $STATUS in
                M|MM|AM) STATUS_TEXT="${YELLOW}[已修改]${NC}" ;;
                A) STATUS_TEXT="${GREEN}[新增已暂存]${NC}" ;;
                D) STATUS_TEXT="${RED}[已删除]${NC}" ;;
                ??) STATUS_TEXT="${BLUE}[新建未跟踪]${NC}" ;;
                R) STATUS_TEXT="${GREEN}[重命名]${NC}" ;;
                *) STATUS_TEXT="[${STATUS}]" ;;
            esac

            printf "%2d) %b %s\n" $((i+1)) "$STATUS_TEXT" "$FILE"
        done

        echo ""
        echo -e "${BLUE}========================================${NC}"
        echo "选择要提交的文件 (支持多种输入方式):"
        echo "  - 单个: 1"
        echo "  - 多个: 1,3,5 或 1 3 5"
        echo "  - 范围: 1-5"
        echo "  - 组合: 1,3-5,7"
        echo "  - 全部: a 或 all"
        echo "  - 取消: q 或 quit"
        echo -e "${BLUE}========================================${NC}"
        read -r SELECTION

        # 处理选择
        if [[ "$SELECTION" =~ ^[qQ](uit)?$ ]]; then
            echo -e "${YELLOW}⚠️  已取消提交。${NC}"
            exit 0
        fi

        # 重置暂存区
        git reset > /dev/null 2>&1

        if [[ "$SELECTION" =~ ^[aA](ll)?$ ]]; then
            # 添加所有文件
            git add .
            echo -e "${GREEN}✅ 已添加所有文件到暂存区。${NC}"
        else
            # 解析选择并添加文件
            SELECTED_INDICES=()

            # 替换逗号为空格
            SELECTION=${SELECTION//,/ }

            for PART in $SELECTION; do
                if [[ $PART =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    # 处理范围
                    START=${BASH_REMATCH[1]}
                    END=${BASH_REMATCH[2]}
                    for ((j=START; j<=END; j++)); do
                        SELECTED_INDICES+=($j)
                    done
                elif [[ $PART =~ ^[0-9]+$ ]]; then
                    # 处理单个数字
                    SELECTED_INDICES+=($PART)
                fi
            done

            # 添加选中的文件
            ADDED_COUNT=0
            for IDX in "${SELECTED_INDICES[@]}"; do
                ARRAY_IDX=$((IDX-1))
                if [ $ARRAY_IDX -ge 0 ] && [ $ARRAY_IDX -lt ${#DISPLAY_FILES[@]} ]; then
                    FILE="${DISPLAY_FILES[$ARRAY_IDX]}"
                    git add "$FILE"
                    echo -e "${GREEN}  ✓${NC} 已添加: $FILE"
                    ((ADDED_COUNT++))
                fi
            done

            if [ $ADDED_COUNT -eq 0 ]; then
                echo -e "${RED}❌ 没有有效的文件被选中。${NC}"
                exit 1
            fi

            echo ""
            echo -e "${GREEN}✅ 共添加 $ADDED_COUNT 个文件到暂存区。${NC}"
        fi
        ;;
esac

# 3. 确认暂存区有内容
if git diff --cached --quiet; then
    echo -e "${YELLOW}⚠️  暂存区为空,没有可提交的文件。${NC}"
    exit 0
fi

# 4. 显示将要提交的文件
echo ""
echo -e "${BLUE}📋 将要提交的文件:${NC}"
git diff --cached --name-status | while read STATUS FILE; do
    case $STATUS in
        M) echo -e "  ${YELLOW}修改:${NC} $FILE" ;;
        A) echo -e "  ${GREEN}新增:${NC} $FILE" ;;
        D) echo -e "  ${RED}删除:${NC} $FILE" ;;
        R*) echo -e "  ${GREEN}重命名:${NC} $FILE" ;;
        *) echo -e "  [$STATUS] $FILE" ;;
    esac
done

# 5. 确定提交信息(使用编辑器)
echo ""
if [ -z "$COMMIT_MSG" ]; then
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}请输入提交信息 (Commit Message):${NC}"
    echo -e "${YELLOW}提示:${NC}"
    echo "  - 将打开文本编辑器进行编辑"
    echo "  - 支持完整的编辑功能(方向键、删除、复制粘贴等)"
    echo "  - 编辑完成后保存并关闭编辑器"
    echo "  - 空文件将使用默认提交信息"
    echo -e "${BLUE}========================================${NC}"

    # 创建临时文件
    TEMP_COMMIT_FILE=$(mktemp /tmp/git-commit-msg.XXXXXX)

    # 添加提示信息到临时文件
    cat > "$TEMP_COMMIT_FILE" << 'EOF'
# 请在上方输入提交信息
#
# 提示:
#   - 第一行是简短的提交摘要(建议不超过50字符)
#   - 空一行后可以写详细描述
#   - 以 '#' 开头的行将被忽略
#
# 示例:
# feat: 添加用户登录功能
#
# - 实现JWT认证
# - 添加密码加密
# - 增加登录日志
EOF

    # 确定使用的编辑器
    if [ -n "$VISUAL" ]; then
        EDITOR_CMD="$VISUAL"
    elif [ -n "$EDITOR" ]; then
        EDITOR_CMD="$EDITOR"
    elif command -v nano &> /dev/null; then
        EDITOR_CMD="nano"
    elif command -v vim &> /dev/null; then
        EDITOR_CMD="vim"
    elif command -v vi &> /dev/null; then
        EDITOR_CMD="vi"
    else
        EDITOR_CMD="cat"
        echo -e "${YELLOW}⚠️  未找到文本编辑器,将使用简单输入模式${NC}"
    fi

    # 打开编辑器
    echo -e "${GREEN}正在打开编辑器: $EDITOR_CMD${NC}"
    echo ""

    if [ "$EDITOR_CMD" = "cat" ]; then
        # 降级方案:使用简单的多行输入
        echo "请输入提交信息 (输入 :wq 或 :q! 结束):"
        COMMIT_LINES=()
        while IFS= read -r line; do
            if [[ "$line" == ":wq" ]] || [[ "$line" == ":q!" ]]; then
                break
            fi
            COMMIT_LINES+=("$line")
        done
        printf "%s\n" "${COMMIT_LINES[@]}" > "$TEMP_COMMIT_FILE"
    else
        $EDITOR_CMD "$TEMP_COMMIT_FILE"
        EDIT_EXIT_CODE=$?

        # 检查编辑器是否正常退出
        if [ $EDIT_EXIT_CODE -ne 0 ]; then
            echo -e "${RED}❌ 编辑器异常退出,操作已取消${NC}"
            rm -f "$TEMP_COMMIT_FILE"
            exit 1
        fi
    fi

    # 读取并处理提交信息
    # 移除注释行和空行
    COMMIT_MSG=$(grep -v '^#' "$TEMP_COMMIT_FILE" | sed '/^$/d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    # 清理临时文件
    rm -f "$TEMP_COMMIT_FILE"

    # 检查是否有有效内容
    if [ -z "$COMMIT_MSG" ]; then
        COMMIT_MSG="Auto commit on $(date +'%Y-%m-%d %H:%M:%S')"
        echo ""
        echo -e "${YELLOW}⚠️  未输入提交信息,使用默认提交信息:${NC}"
        echo -e "${YELLOW}   $COMMIT_MSG${NC}"
    else
        # 计算行数
        LINE_COUNT=$(echo "$COMMIT_MSG" | wc -l)
        echo ""
        echo -e "${GREEN}✅ 已接收提交信息 (共 $LINE_COUNT 行)${NC}"
        echo -e "${BLUE}预览:${NC}"
        echo "$COMMIT_MSG" | sed 's/^/  /'
    fi
fi

# 6. 执行 git commit
echo ""
echo -e "${BLUE}📝 正在提交...${NC}"
if git commit -m "$COMMIT_MSG"; then
    echo -e "${GREEN}✅ 提交成功!${NC}"
else
    echo -e "${RED}❌ 提交失败,请检查错误信息。${NC}"
    exit 1
fi

# 7. 执行 git push
echo ""
echo -e "${BLUE}📤 正在推送到远程仓库...${NC}"
if git push; then
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}🎉 推送成功! 代码已更新到远程仓库。${NC}"
    echo -e "${GREEN}============================================${NC}"
else
    echo -e "${RED}❌推送失败,请检查远程分支和网络连接。${NC}"
    exit 1
fi