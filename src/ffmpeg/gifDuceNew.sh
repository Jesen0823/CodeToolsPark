#!/bin/bash
set -e

# 颜色和状态输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 检查输入参数
if [ $# -lt 4 ]; then
    echo -e "${RED}错误：参数不足${NC}"
    echo -e "${YELLOW}使用方法:${NC} $0 输入视频 输出GIF 开始时间 持续时间 [帧率] [宽度]"
    echo -e "${YELLOW}示例:${NC} $0 input.mp4 output.gif 00:01:00 00:00:10 15 640"
    exit 1
fi

# 基本参数
INPUT_FILE="$1"
OUTPUT_FILE="$2"
START_TIME="$3"
DURATION="$4"

# 视频处理参数 - 可根据需要修改
FPS=${5:-15}                 # 帧率，默认15
WIDTH=${6:-480}              # 宽度，默认480px，高度自动计算
INTERPOLATION="lanczos"      # 缩放插值算法，lanczos质量较高

# 调色板生成参数
MAX_COLORS=256               # GIF最多256色
RESERVE_TRANSPARENT="on"     # 保留透明色
STATS_MODE="full"            # 统计模式: full（全帧）, diff（差异）, single（单帧）

# 调色板应用参数
DITHER="floyd_steinberg"     # 抖动算法: bayer, heckbert, floyd_steinberg, sierra2等
BAYER_SCALE=3                # Bayer抖动比例(0-5)
DIFF_MODE="rectangle"        # 差异模式: rectangle（矩形）, none（无）
NEW_PALETTE="off"            # 是否为每帧使用新调色板

# 临时文件
PALETTE="/tmp/palette.png"   # 调色板临时文件

echo -e "${GREEN}开始处理视频:${NC} $INPUT_FILE"
echo -e "${GREEN}输出GIF:${NC} $OUTPUT_FILE"
echo -e "${GREEN}参数:${NC} 开始=$START_TIME, 时长=$DURATION, 帧率=$FPS, 宽度=$WIDTH"

# 第一阶段：生成调色板
echo -e "${YELLOW}正在生成调色板...${NC}"
ffmpeg -y -ss "$START_TIME" -t "$DURATION" -i "$INPUT_FILE" \
  -vf "fps=$FPS,scale=${WIDTH}:-1:flags=$INTERPOLATION,palettegen=max_colors=$MAX_COLORS:reserve_transparent=$RESERVE_TRANSPARENT:stats_mode=$STATS_MODE" \
  "$PALETTE" || { echo -e "${RED}生成调色板失败${NC}"; exit 1; }

# 第二阶段：使用调色板生成GIF
echo -e "${YELLOW}正在生成GIF...${NC}"
ffmpeg -y -ss "$START_TIME" -t "$DURATION" -i "$INPUT_FILE" -i "$PALETTE" \
  -lavfi "fps=$FPS,scale=${WIDTH}:-1:flags=$INTERPOLATION[x];[x][1:v]paletteuse=dither=$DITHER:bayer_scale=$BAYER_SCALE:diff_mode=$DIFF_MODE:new=$NEW_PALETTE" \
  -loop 0 "$OUTPUT_FILE" || { echo -e "${RED}生成GIF失败${NC}"; exit 1; }

# 清理临时文件
rm -f "$PALETTE"

echo -e "${GREEN}处理完成!${NC}"
echo -e "${GREEN}文件位置:${NC} $OUTPUT_FILE"

# 调用： ./gifDuceNew.sh "input.mp4" "out-1.gif" 00:00:00 00:00:05  15  360


# 分阶段处理：
# -- 将调色板生成和应用分为两个步骤，这样可以更精确地控制每个阶段的参数，并且可以保存调色板用于调试。
# 改进的调色板参数：
# -- 使用 stats_mode=full 以获得更准确的全局调色板
# -- 默认使用 floyd_steinberg 抖动算法，这通常能提供更好的视觉效果

# 增强的错误处理：
# -- 添加了参数检查和错误提示
# -- 每个 FFmpeg 命令都有错误检查
# -- 使用颜色输出增强可读性

# 性能优化：
# -- 使用了更高效的滤镜图结构
# -- 更友好的用户界面：
# ----- 添加了进度提示
# ----- 显示处理参数
# ----- 自动清理临时文件

# 使用建议
# -- 参数调整：
# ----- 对于动作快速的视频，可以考虑降低 FPS（如 10-12）
# ----- 对于细节丰富的视频，可以增加 MAX_COLORS（但不要超过 256）
# ----- 对于有透明度的视频，确保 RESERVE_TRANSPARENT=on

# 质量 vs 大小：
# -- 如果生成的 GIF 文件过大，可以尝试：
# -- 减小 WIDTH 参数
# -- 使用 DITHER=bayer 和调整 BAYER_SCALE=4 或 5
# -- 使用 stats_mode=diff 只关注帧间变化

# 特殊场景：
# -- 对于动画类视频，NEW_PALETTE=on 可能会提供更好的效果
# -- 对于静态场景较多的视频，DIFF_MODE=rectangle 可以减小文件大小