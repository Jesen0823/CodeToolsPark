#!/bin/bash
# 质量对比测试脚本 - 快速生成平衡模式和质量优先模式的对比文件

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查参数
if [ $# -lt 2 ]; then
    echo -e "${RED}错误：参数不足${NC}"
    echo -e "${YELLOW}使用方法:${NC} $0 <输入视频> <输出目录> [格式] [开始时间] [时长]"
    echo -e "${YELLOW}格式:${NC} gif, apng, webp, all（默认all）"
    echo -e "${YELLOW}示例:${NC}"
    echo -e "  $0 input.mp4 ./output all 00:00:00 00:00:10"
    echo -e "  $0 input.mp4 ./output gif 00:00:00 00:00:05"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_DIR="$2"
FORMAT="${3:-all}"
START_TIME="${4:-00:00:00}"
DURATION="${5:-00:00:10}"

# 验证输入文件
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}错误：输入文件不存在 $INPUT_FILE${NC}"
    exit 1
fi

# 创建输出目录
mkdir -p "$OUTPUT_DIR"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/src/ffmpeg" && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         质量对比测试 - 平衡模式 vs 质量优先模式          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}输入文件:${NC} $INPUT_FILE"
echo -e "${GREEN}输出目录:${NC} $OUTPUT_DIR"
echo -e "${GREEN}格式:${NC} $FORMAT"
echo -e "${GREEN}时间范围:${NC} $START_TIME - $DURATION"
echo ""

# 测试 GIF
test_gif() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}测试 GIF 格式${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "${BLUE}[1/2] 生成平衡模式 GIF...${NC}"
    "$SCRIPT_DIR/video2gif.sh" "$INPUT_FILE" "$OUTPUT_DIR/balanced.gif" "$START_TIME" "$DURATION" 30 1080
    BALANCED_SIZE=$(du -m "$OUTPUT_DIR/balanced.gif" | cut -f1)
    echo -e "${GREEN}✓ 完成 - 文件大小: ${BALANCED_SIZE}MB${NC}"

    echo -e "${BLUE}[2/2] 生成质量优先 GIF...${NC}"
    "$SCRIPT_DIR/video2gif.sh" "$INPUT_FILE" "$OUTPUT_DIR/quality_first.gif" "$START_TIME" "$DURATION" 30 1080 true
    QUALITY_SIZE=$(du -m "$OUTPUT_DIR/quality_first.gif" | cut -f1)
    echo -e "${GREEN}✓ 完成 - 文件大小: ${QUALITY_SIZE}MB${NC}"

    # 计算差异
    SIZE_DIFF=$((QUALITY_SIZE - BALANCED_SIZE))
    SIZE_PERCENT=$((SIZE_DIFF * 100 / BALANCED_SIZE))

    echo ""
    echo -e "${GREEN}对比结果:${NC}"
    echo -e "  平衡模式:    ${BALANCED_SIZE}MB"
    echo -e "  质量优先:    ${QUALITY_SIZE}MB"
    echo -e "  增长:        +${SIZE_DIFF}MB (+${SIZE_PERCENT}%)"
    echo ""
}

# 测试 APNG
test_apng() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}测试 APNG 格式${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "${BLUE}[1/2] 生成平衡模式 APNG...${NC}"
    "$SCRIPT_DIR/video2apng.sh" "$INPUT_FILE" "$OUTPUT_DIR/balanced.apng" "$START_TIME" "$DURATION" 30 1080 5
    BALANCED_SIZE=$(du -m "$OUTPUT_DIR/balanced.apng" | cut -f1)
    echo -e "${GREEN}✓ 完成 - 文件大小: ${BALANCED_SIZE}MB${NC}"

    echo -e "${BLUE}[2/2] 生成质量优先 APNG...${NC}"
    "$SCRIPT_DIR/video2apng.sh" "$INPUT_FILE" "$OUTPUT_DIR/quality_first.apng" "$START_TIME" "$DURATION" 30 1080 3 true
    QUALITY_SIZE=$(du -m "$OUTPUT_DIR/quality_first.apng" | cut -f1)
    echo -e "${GREEN}✓ 完成 - 文件大小: ${QUALITY_SIZE}MB${NC}"

    # 计算差异
    SIZE_DIFF=$((QUALITY_SIZE - BALANCED_SIZE))
    SIZE_PERCENT=$((SIZE_DIFF * 100 / BALANCED_SIZE))

    echo ""
    echo -e "${GREEN}对比结果:${NC}"
    echo -e "  平衡模式:    ${BALANCED_SIZE}MB"
    echo -e "  质量优先:    ${QUALITY_SIZE}MB"
    echo -e "  增长:        +${SIZE_DIFF}MB (+${SIZE_PERCENT}%)"
    echo ""
}

# 测试 WebP
test_webp() {
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}测试 WebP 格式${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    echo -e "${BLUE}[1/2] 生成平衡模式 WebP...${NC}"
    "$SCRIPT_DIR/video2webp_stand.sh" "$INPUT_FILE" "$OUTPUT_DIR/balanced.webp" "$START_TIME" "$DURATION" 30 1080 90
    BALANCED_SIZE=$(du -m "$OUTPUT_DIR/balanced.webp" | cut -f1)
    echo -e "${GREEN}✓ 完成 - 文件大小: ${BALANCED_SIZE}MB${NC}"

    echo -e "${BLUE}[2/2] 生成质量优先 WebP...${NC}"
    "$SCRIPT_DIR/video2webp_stand.sh" "$INPUT_FILE" "$OUTPUT_DIR/quality_first.webp" "$START_TIME" "$DURATION" 30 1080 95 true
    QUALITY_SIZE=$(du -m "$OUTPUT_DIR/quality_first.webp" | cut -f1)
    echo -e "${GREEN}✓ 完成 - 文件大小: ${QUALITY_SIZE}MB${NC}"

    # 计算差异
    SIZE_DIFF=$((QUALITY_SIZE - BALANCED_SIZE))
    SIZE_PERCENT=$((SIZE_DIFF * 100 / BALANCED_SIZE))

    echo ""
    echo -e "${GREEN}对比结果:${NC}"
    echo -e "  平衡模式:    ${BALANCED_SIZE}MB"
    echo -e "  质量优先:    ${QUALITY_SIZE}MB"
    echo -e "  增长:        +${SIZE_DIFF}MB (+${SIZE_PERCENT}%)"
    echo ""
}

# 执行测试
case "$FORMAT" in
    gif)
        test_gif
        ;;
    apng)
        test_apng
        ;;
    webp)
        test_webp
        ;;
    all)
        test_gif
        test_apng
        test_webp
        ;;
    *)
        echo -e "${RED}错误：不支持的格式 $FORMAT${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      测试完成！                           ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}输出文件位置:${NC} $OUTPUT_DIR"
echo ""
echo -e "${YELLOW}对比建议:${NC}"
echo -e "  1. 用图片查看器打开两个文件"
echo -e "  2. 对比肤色饱满度、毛发清晰度、细节锐度"
echo -e "  3. 根据需求选择合适的模式"
echo ""
echo -e "${YELLOW}文件命名规则:${NC}"
echo -e "  balanced.{gif|apng|webp}     - 平衡模式（压缩优先）"
echo -e "  quality_first.{gif|apng|webp} - 质量优先（极致还原）"
echo ""
