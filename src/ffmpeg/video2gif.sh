#!/bin/bash
set -e

# 颜色和状态输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# 检查FFmpeg和FFprobe是否可用
command -v ffmpeg >/dev/null 2>&1 || { echo -e "${RED}错误：未找到ffmpeg命令，请确保已安装FFmpeg${NC}"; exit 1; }
command -v ffprobe >/dev/null 2>&1 || { echo -e "${RED}错误：未找到ffprobe命令，请确保已安装FFmpeg${NC}"; exit 1; }

# 检查输入参数
if [ $# -lt 4 ]; then
    echo -e "${RED}错误：参数不足${NC}"
    echo -e "${YELLOW}使用方法:${NC} ./$0 输入视频 输出GIF 开始时间 持续时间 [帧率] [宽度]"
    echo -e "${YELLOW}示例:${NC} ./$0 input.mp4 output.gif 00:01:00 00:00:10 15 640"
    echo -e "${YELLOW}注意:${NC} 必须使用相对路径./$0执行，不能使用绝对路径/$0"
    exit 1
fi

# 检查输入文件是否存在
if [ ! -f "$1" ]; then
    echo -e "${RED}错误：输入文件不存在: $1${NC}"
    echo -e "${YELLOW}提示:${NC} 请确保文件路径正确，包含特殊字符的文件名请用双引号包裹"
    exit 1
fi

# 基本参数
# 增强Git Bash兼容性：使用printf %q确保特殊字符正确转义
INPUT_FILE="$1"
OUTPUT_FILE="$2"
START_TIME="$3"
DURATION="$4"

# 针对Git Bash环境的特殊处理
if [[ $(uname -a) =~ Msys || $(uname -a) =~ mingw ]]; then
    # 在Git Bash中，将路径转换为Windows格式并确保特殊字符正确处理
    INPUT_FILE=$(cygpath -w "$INPUT_FILE" 2>/dev/null || echo "$INPUT_FILE")
    OUTPUT_FILE=$(cygpath -w "$OUTPUT_FILE" 2>/dev/null || echo "$OUTPUT_FILE")
fi

# 视频处理参数
FPS=${5:-24}                 # 帧率，默认24（与其他脚本保持一致）
WIDTH=${6:-800}              # 宽度，默认800px（与其他脚本保持一致）
INTERPOLATION="lanczos"      # 缩放插值算法，lanczos质量较高

# 调色板生成参数
MAX_COLORS=256               # GIF最多256色
RESERVE_TRANSPARENT="on"     # 保留透明色
STATS_MODE="full"            # 统计模式: full（全帧）, diff（差异）, single（单帧）

# 移除threshold参数以提高兼容性，不是所有FFmpeg版本都支持此参数
THRESHOLD_OPTION=""

# 调色板应用参数
DITHER="floyd_steinberg"     # 抖动算法: bayer, heckbert, floyd_steinberg, sierra2等（floyd_steinberg视觉效果更好）
DIFF_MODE="rectangle"        # 差异模式: rectangle（矩形）, none（无）
NEW_PALETTE="off"            # 是否为每帧使用新调色板

# 核心：将DURATION（HH:MM:SS）转换为总秒数，用于动态计算帧数
# 支持格式：SS、MM:SS、HH:MM:SS
convert_duration_to_seconds() {
    local duration="$1"
    # 使用awk解析时间格式并转换为秒
    echo "$duration" | awk -F: '
        {
            if (NF == 1) {  # 仅秒（如 "5" 表示5秒）
                print $1
            } else if (NF == 2) {  # 分:秒（如 "00:05" 表示5秒）
                print $1 * 60 + $2
            } else if (NF == 3) {  # 时:分:秒（如 "00:00:05" 表示5秒）
                print $1 * 3600 + $2 * 60 + $3
            }
        }'
}

# 计算实际需要的帧数 = FPS × 时长(秒)
DURATION_SECONDS=$(convert_duration_to_seconds "$DURATION")
CALCULATED_FRAMES=$(( FPS * DURATION_SECONDS ))

# 临时文件：使用操作系统的临时目录
if [[ -n "$TMPDIR" ]]; then
    PALETTE="$TMPDIR/palette.png"
elif [[ -n "$TEMP" ]]; then
    PALETTE="$TEMP/palette.png"
elif [[ -n "$TMP" ]]; then
    PALETTE="$TMP/palette.png"
else
    PALETTE="./palette.png"  # 默认使用当前目录
fi

echo -e "${GREEN}开始处理视频:${NC} $INPUT_FILE"
echo -e "${GREEN}输出GIF:${NC} $OUTPUT_FILE"
echo -e "${GREEN}参数:${NC} 开始=$START_TIME, 时长=$DURATION($DURATION_SECONDS秒), 帧率=$FPS, 宽度=$WIDTH"
echo -e "${GREEN}帧数控制:${NC} 计算所需帧数=$CALCULATED_FRAMES"

# 检查输入视频分辨率，仅对720p以上视频应用色彩空间转换
RESOLUTION=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$INPUT_FILE")
WIDTH_SRC=$(echo $RESOLUTION | cut -d'x' -f1)
HEIGHT_SRC=$(echo $RESOLUTION | cut -d'x' -f2)

if [ $HEIGHT_SRC -ge 720 ]; then
    COLORSPACE_OPTION=":out_color_matrix=bt709"
else
    COLORSPACE_OPTION=""
fi

# 第一阶段：生成调色板（优化人物细节和兼容性）
echo -e "${YELLOW}正在生成调色板...${NC}"
# 极低的降噪参数，最大程度保留人物面部和身体细节
# 轻微的锐化，保持自然效果
# 适度的色彩调整，提高亮度和对比度
ffmpeg -y -ss "$START_TIME" -t "$DURATION" -i "$INPUT_FILE" \
  -vf "fps=$FPS,hqdn3d=0.3:0.2:0.8:0.6,scale=${WIDTH}:-1:flags=$INTERPOLATION$COLORSPACE_OPTION,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02,palettegen=max_colors=$MAX_COLORS:reserve_transparent=$RESERVE_TRANSPARENT:stats_mode=$STATS_MODE$THRESHOLD_OPTION" \
  -frames:v 1 \
  -safe 0 \
  "$PALETTE" || { echo -e "${RED}生成调色板失败${NC}"; exit 1; }

# 第二阶段：使用调色板生成GIF（优化人物细节和兼容性）
echo -e "${YELLOW}正在生成GIF...${NC}"
# 使用与调色板生成阶段相同的滤镜参数
# 极低的降噪参数，最大程度保留人物面部和身体细节
# 确保人物细节在最终GIF中得到保留
ffmpeg -y -ss "$START_TIME" -t "$DURATION" -i "$INPUT_FILE" -i "$PALETTE" \
  -lavfi "fps=$FPS,hqdn3d=0.3:0.2:0.8:0.6,scale=${WIDTH}:-1:flags=$INTERPOLATION$COLORSPACE_OPTION,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02[x];[x][1:v]paletteuse=dither=$DITHER:diff_mode=$DIFF_MODE:new=$NEW_PALETTE" \
  -loop 0 \
  -safe 0 \
  "$OUTPUT_FILE" || { echo -e "${RED}生成GIF失败${NC}"; exit 1; }

# 清理临时文件
rm -f "$PALETTE"

echo -e "${GREEN}处理完成!${NC}"
echo -e "${GREEN}文件位置:${NC} $OUTPUT_FILE"

# 调用： ./video2gif.sh "input.mp4" "out-1.gif" 00:00:00 00:00:05  15  360

# 方案二：在PowerShell中直接使用FFmpeg命令（Windows环境下使用）
# 第一步：生成调色板
# 替换以下参数：
#   <INPUT_FILE>: 输入视频文件路径
#   <START_TIME>: 开始时间，格式：HH:MM:SS
#   <DURATION>: 持续时间，格式：HH:MM:SS
#   <FPS>: 帧率
#   <WIDTH>: 输出宽度
#   <PALETTE_FILE>: 临时调色板文件路径
#ffmpeg -y -ss <START_TIME> -t <DURATION> -i "<INPUT_FILE>" -vf "fps=<FPS>,hqdn3d=0.3:0.2:0.8:0.6,scale=<WIDTH>:-1:flags=lanczos,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02,palettegen=max_colors=256:reserve_transparent=on:stats_mode=full" -frames:v 1 "<PALETTE_FILE>"

# 第二步：生成GIF
# 替换以下参数：
#   <INPUT_FILE>: 输入视频文件路径
#   <OUTPUT_FILE>: 输出GIF文件路径
#   <START_TIME>: 开始时间，格式：HH:MM:SS
#   <DURATION>: 持续时间，格式：HH:MM:SS
#   <FPS>: 帧率
#   <WIDTH>: 输出宽度
#   <PALETTE_FILE>: 临时调色板文件路径
#ffmpeg -y -ss <START_TIME> -t <DURATION> -i "<INPUT_FILE>" -i "<PALETTE_FILE>" -lavfi "fps=<FPS>,hqdn3d=0.3:0.2:0.8:0.6,scale=<WIDTH>:-1:flags=lanczos,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02[x];[x][1:v]paletteuse=dither=floyd_steinberg:diff_mode=rectangle:new=off" -loop 0 "<OUTPUT_FILE>"

# 第三步：清理临时调色板文件
#Remove-Item -Force "<PALETTE_FILE>"

# 示例：
# 生成调色板
#ffmpeg -y -ss 00:09:00 -t 00:00:05 -i "朗读者.1080p.BD中英双字.mp4" -vf "fps=25,hqdn3d=0.3:0.2:0.8:0.6,scale=720:-1:flags=lanczos,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02,palettegen=max_colors=256:reserve_transparent=on:stats_mode=full" -frames:v 1 "./palette.png"

# 生成GIF
#ffmpeg -y -ss 00:09:00 -t 00:00:05 -i "朗读者.1080p.BD中英双字.mp4" -i "./palette.png" -lavfi "fps=25,hqdn3d=0.3:0.2:0.8:0.6,scale=720:-1:flags=lanczos,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02[x];[x][1:v]paletteuse=dither=floyd_steinberg:diff_mode=rectangle:new=off" -loop 0 "朗读者.1080p.BD中英双字-001.gif"

# 清理临时文件
#Remove-Item -Force "./palette.png"


# 分阶段处理：
# -- 将调色板生成和应用分为两个步骤，这样可以更精确地控制每个阶段的参数，并且可以保存调色板用于调试。
# 改进的调色板参数：
# -- 使用 stats_mode=full 以获得更准确的全局调色板
# -- 默认使用 floyd_steinberg 抖动算法，这通常能提供更好的视觉效果

# 增强的错误处理：
# -- 添加了参数检查和错误提示
# -- 每个 FFmpeg 命令都有错误检查
# -- 使用颜色输出增强可读性

# 1. 缩放与插值 
#   •  scale 参数： 
#    ◦ 保持原始宽高比（使用 -1 自动计算高度） 
#    ◦ 避免过度缩放（如原始视频为 1080p，直接缩放到 320px 会损失细节） 
#    ◦ 建议：设置 WIDTH 为 640 或更高（根据原始分辨率调整）
#   •  INTERPOLATION 参数：
#    ◦ 使用 "lanczos" 插值算法（已在脚本中使用，这是高质量缩放的首选）
# 2. 调色板生成 
#   • MAX_COLORS： 
#    ◦ 增加到 256（脚本中已设置），人物图像通常需要丰富的色彩   
#   • STATS_MODE： 
#    ◦ 使用 "full"（已优化）以分析整段视频的色彩分布   
#   • 添加 threshold 参数： 
#    ◦ 控制颜色聚类的敏感度，添加 threshold=90 以保留更多细节
# 3. 抖动算法
#   • DITHER： 
#    ◦ 使用 "floyd_steinberg"（已优化），这是保留细节的最佳选择   
#   • 避免 bayer 抖动：
#    ◦ 虽然 Bayer 抖动可减小文件大小，但会引入明显的棋盘格伪影

# 4. 增强人物清晰度
#   •添加锐化滤镜 
#    ◦在缩放后添加轻微锐化，恢复因压缩损失的边缘细节，在生成调色板和应用调色板的命令中添加锐化滤镜：
#    -vf "fps=$FPS,scale=${WIDTH}:-1:flags=$INTERPOLATION,unsharp=5:5:0.8:3:3:0.4"
#    unsharp=5:5:0.8:3:3:0.4 表示：
#       亮度锐化半径 = 5，强度 = 0.8
#       色度锐化半径 = 3，强度 = 0.4
# 5.处理肤色细节
#   •使用 colorspace=bt709 确保肤色准确（适用于高清视频）
#     -vf "fps=$FPS,scale=${WIDTH}:-1:flags=$INTERPOLATION,colorspace=bt709"

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
# -- 减小 WIDTH 参数，但不低于 480px
# -- 使用 DITHER=bayer 和调整 BAYER_SCALE=4 或 5
# -- 使用 stats_mode=diff 只关注帧间变化

# 特殊场景：
# -- 对于动画类视频，NEW_PALETTE=on 可能会提供更好的效果
# -- 对于静态场景较多的视频，DIFF_MODE=rectangle 可以减小文件大小
# -- 对于极致清晰度需求
# ------ 可考虑使用 Gifsicle 优化：
# -------- gifsicle -O3 --colors 256 input.gif -o output_optimized.gif
# ------ 转换为 WebP/APNG:
# -------- ffmpeg -i input.mp4 -vf "fps=15,scale=640:-1" -lossless 0 -q:v 80 output.webp