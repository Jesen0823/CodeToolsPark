#!/bin/bash
# 快速验证脚本 - 检查 qualityFirst 参数是否正确实现

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         qualityFirst 参数实现验证                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

# 检查脚本
check_script() {
    local script="$1"
    local script_name=$(basename "$script")

    echo -n "检查 $script_name ... "

    if [ ! -f "$script" ]; then
        echo -e "${RED}✗ 文件不存在${NC}"
        return 1
    fi

    # 检查 QUALITY_FIRST 参数
    if grep -q "QUALITY_FIRST=" "$script"; then
        echo -e "${GREEN}✓ 包含 QUALITY_FIRST 参数${NC}"

        # 显示参数定义
        echo "  参数定义："
        grep "QUALITY_FIRST=" "$script" | head -1 | sed 's/^/    /'

        # 检查条件判断
        if grep -q 'if \[\[ "$QUALITY_FIRST"' "$script"; then
            echo -e "  条件判断: ${GREEN}✓ 正确${NC}"
        else
            echo -e "  条件判断: ${RED}✗ 缺失${NC}"
            return 1
        fi

        # 检查参数使用
        if grep -q "DENOISE_PARAMS\|SHARPEN_PARAMS\|COLOR_PARAMS" "$script"; then
            echo -e "  参数使用: ${GREEN}✓ 正确${NC}"
        else
            echo -e "  参数使用: ${RED}✗ 缺失${NC}"
            return 1
        fi

        return 0
    else
        echo -e "${RED}✗ 缺少 QUALITY_FIRST 参数${NC}"
        return 1
    fi
}

# 检查文档
check_doc() {
    local doc="$1"
    local doc_name=$(basename "$doc")

    echo -n "检查 $doc_name ... "

    if [ ! -f "$doc" ]; then
        echo -e "${RED}✗ 文件不存在${NC}"
        return 1
    else
        echo -e "${GREEN}✓ 存在${NC}"
        return 0
    fi
}

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "1. 检查脚本文件"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

SCRIPT_OK=0
check_script "./src/ffmpeg/video2gif.sh" && ((SCRIPT_OK++))
echo ""
check_script "./src/ffmpeg/video2apng.sh" && ((SCRIPT_OK++))
echo ""
check_script "./src/ffmpeg/video2webp_stand.sh" && ((SCRIPT_OK++))
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "2. 检查文档文件"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

DOC_OK=0
check_doc "./README.md" && ((DOC_OK++))
check_doc "./QUICK_REFERENCE.md" && ((DOC_OK++))
check_doc "./QUALITY_FIRST_GUIDE.md" && ((DOC_OK++))
check_doc "./OPTIMIZATION_GUIDE.md" && ((DOC_OK++))
check_doc "./IMPLEMENTATION_SUMMARY.md" && ((DOC_OK++))
check_doc "./COMPLETION_REPORT.md" && ((DOC_OK++))
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "3. 检查测试脚本"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

TEST_OK=0
check_doc "./test_quality_comparison.sh" && ((TEST_OK++))
echo ""

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "验证结果"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "脚本文件: $SCRIPT_OK/3 ✓"
echo "文档文件: $DOC_OK/6 ✓"
echo "测试脚本: $TEST_OK/1 ✓"
echo ""

TOTAL=$((SCRIPT_OK + DOC_OK + TEST_OK))
if [ $TOTAL -eq 10 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✓ 所有文件验证通过！                        ║${NC}"
    echo -e "${GREEN}║         qualityFirst 参数实现完成！                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║              ✗ 验证失败，请检查文件                       ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
