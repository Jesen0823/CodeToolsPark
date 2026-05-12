#!/bin/bash
set -e

# 高级人像视频转动态图工具 - 使用优化库
# 支持GIF、APNG、WebP三种格式，自动优化参数

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查依赖
command -v ffmpeg >/dev/null 2>&1 || { echo -e "${RED}错误：未找到ffmpeg${NC}"; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo -e "${RED}错误：未找到ffprobe${NC}"; exit 1; }

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/video_optimize_lib.sh" || { echo -e "${RED}错误：无法加载优化库${NC}"; exit 1; }

# 使用说明
usage() {
    cat << EOF
${GREEN}高级人像视频转动态图工具${NC}

${YELLOW}使用方法:${NC}
  $0 <格式> <输入视频> <输出文件> <开始时间> <时长> [选项]

${YELLOW}格式:${NC}
  gif, apng, webp

${YELLOW}选项:${NC}
  --fps <帧率>              帧率（默认自动优化）
  --width <宽度>            宽度（默认自动优化）
  --quality <质量>          质量（APNG/WebP: 0-100，默认90）
  --denoise <预设>          降噪预设（minimal/light/moderate/strong，默认light）
  --sharpen <预设>          锐化预设（subtle/normal/strong/extreme，默认normal）
  --color <预设>            色彩预设（natural/portrait/vivid/cinema，默认portrait）
  --auto                    自动优化所有参数

${YELLOW}示例:${NC}
  # 自动优化生成WebP
  $0 webp input.mp4 output.webp 00:00:00 00:00:10 --auto

  # 手动指定参数生成APNG
  $0 apng input.mp4 output.apng 00:00:00 00:00:10 --fps 30 --width 1080 --quality 95

  # 生成高质量GIF
  $0 gif input.mp4 output.gif 00:00:00 00:00:05 --denoise light --sharpen strong

EOF
    exit 1
}

# 参数检查
if [ $# -lt 5 ]; then
    usage
fi

FORMAT="$1"
INPUT_FILE="$2"
OUTPUT_FILE="$3"
START_TIME="$4"
DURATION="$5"
shift 5

# 验证格式
case "$FORMAT" in
    gif|apng|webp) ;;
    *) echo -e "${RED}错误：不支持的格式 $FORMAT${NC}"; exit 1 ;;
esac

# 验证输入文件
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}错误：输入文件不存在 $INPUT_FILE${NC}"
    exit 1
fi

# 默认参数
AUTO_OPTIMIZE=false
FPS=""
WIDTH=""
QUALITY="90"
DENOISE_PRESET="light"
SHARPEN_PRESET="normal"
COLOR_PRESET="portrait"

# 解析选项
while [ $# -gt 0 ]; do
    case "$1" in
        --fps) FPS="$2"; shift 2 ;;
        --width) WIDTH="$2"; shift 2 ;;
        --quality) QUALITY="$2"; shift 2 ;;
        --denoise) DENOISE_PRESET="$2"; shift 2 ;;
        --sharpen) SHARPEN_PRESET="$2"; shift 2 ;;
        --color) COLOR_PRESET="$2"; shift 2 ;;
        --auto) AUTO_OPTIMIZE=true; shift ;;
        *) echo -e "${RED}未知选项: $1${NC}"; usage ;;
    esac
done

# 获取视频信息
echo -e "${BLUE}正在分析源视频...${NC}"
VIDEO_INFO=$(get_video_info "$INPUT_FILE")
SOURCE_WIDTH=$(echo "$VIDEO_INFO" | cut -d'x' -f1)
SOURCE_HEIGHT=$(echo "$VIDEO_INFO" | cut -d'x' -f2)
SOURCE_FPS=$(echo "$VIDEO_INFO" | cut -d'x' -f3 | cut -d'/' -f1)

echo -e "${GREEN}源视频信息:${NC} ${SOURCE_WIDTH}x${SOURCE_HEIGHT} @ ${SOURCE_FPS}fps"

# 自动优化参数
if [ "$AUTO_OPTIMIZE" = true ]; then
    echo -e "${BLUE}自动优化参数...${NC}"
    FPS=$(calculate_optimal_fps "$SOURCE_FPS" 30)
    WIDTH=$(calculate_optimal_width "$SOURCE_WIDTH" 1080)
    echo -e "${GREEN}优化后:${NC} FPS=$FPS, WIDTH=$WIDTH"
else
    # 使用用户指定或默认值
    FPS="${FPS:-30}"
    WIDTH="${WIDTH:-1080}"
fi

# 时长转秒
convert_duration_to_seconds() {
    echo "$1" | awk -F: '{
        if (NF == 1) print $1
        else if (NF == 2) print $1 * 60 + $2
        else if (NF == 3) print $1 * 3600 + $2 * 60 + $3
    }'
}

DURATION_SECONDS=$(convert_duration_to_seconds "$DURATION")
ESTIMATED_SIZE=$(estimate_file_size "$FORMAT" "$FPS" "$WIDTH" "$DURATION_SECONDS" "$QUALITY")

echo -e "${YELLOW}处理参数:${NC}"
echo "  格式: $FORMAT"
echo "  帧率: $FPS fps"
echo "  宽度: $WIDTH px"
echo "  时长: $DURATION ($DURATION_SECONDS秒)"
echo "  质量: $QUALITY"
echo "  降噪: $DENOISE_PRESET"
echo "  锐化: $SHARPEN_PRESET"
echo "  色彩: $COLOR_PRESET"
echo -e "  ${BLUE}预估文件大小: ~${ESTIMATED_SIZE}MB${NC}"

# 生成滤镜链
case "$FORMAT" in
    gif)
        FILTER=$(generate_gif_filter "$FPS" "$WIDTH" "$DENOISE_PRESET" "$SHARPEN_PRESET" "$COLOR_PRESET" "bt709")
        echo -e "${YELLOW}正在生成GIF...${NC}"

        # 生成调色板
        PALETTE="/tmp/palette_$$.png"
        ffmpeg -y -ss "$START_TIME" -t "$DURATION" -i "$INPUT_FILE" \
            -vf "${FILTER},palettegen=max_colors=256:reserve_transparent=on:stats_mode=full:threshold=90" \
            -frames:v 1 -safe 0 "$PALETTE" || { echo -e "${RED}生成调色板失败${NC}"; exit 1; }

        # 应用调色板生成GIF
        ffmpeg -y -ss "$START_TIME" -t "$DURATION" -i "$INPUT_FILE" -i "$PALETTE" \
            -lavfi "${FILTER}[x];[x][1:v]paletteuse=dither=floyd_steinberg:diff_mode=rectangle:new=off" \
            -loop 0 -safe 0 "$OUTPUT_FILE" || { echo -e "${RED}生成GIF失败${NC}"; exit 1; }

        rm -f "$PALETTE"
        ;;

    apng)
        FILTER=$(generate_apng_filter "$FPS" "$WIDTH" "$DENOISE_PRESET" "$SHARPEN_PRESET" "$COLOR_PRESET" "bt709" 0)
        echo -e "${YELLOW}正在生成APNG...${NC}"

        ffmpeg -y -ss "$START_TIME" -t "$DURATION" -i "$INPUT_FILE" \
            -vf "$FILTER" \
            -c:v apng -compression_level 5 -plays 0 -pred mixed -f apng -safe 0 "$OUTPUT_FILE" \
            || { echo -e "${RED}生成APNG失败${NC}"; exit 1; }
        ;;

    webp)
        FILTER=$(generate_webp_filter "$FPS" "$WIDTH" "$DENOISE_PRESET" "$SHARPEN_PRESET" "$COLOR_PRESET" "bt709" 0)
        echo -e "${YELLOW}正在生成WebP...${NC}"

        ffmpeg -y -ss "$START_TIME" -t "$DURATION" -i "$INPUT_FILE" \
            -vf "$FILTER" \
            -c:v libwebp -loop 0 -qscale:v "$QUALITY" -compression_level 6 -method 6 -preset photo -an -safe 0 "$OUTPUT_FILE" \
            || { echo -e "${RED}生成WebP失败${NC}"; exit 1; }
        ;;
esac

# 获取实际文件大小
ACTUAL_SIZE=$(du -m "$OUTPUT_FILE" | cut -f1)
echo -e "${GREEN}处理完成!${NC}"
echo -e "${GREEN}输出文件:${NC} $OUTPUT_FILE"
echo -e "${GREEN}实际大小:${NC} ${ACTUAL_SIZE}MB"

# 打印优化建议
print_optimization_tips "$FORMAT" "$ACTUAL_SIZE"
