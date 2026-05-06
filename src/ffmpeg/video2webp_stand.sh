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
echo -e "${YELLOW}使用方法:${NC} ./$0 输入视频 输出WebP(必须带.webp扩展名) 开始时间 持续时间 [帧率] [宽度] [质量(0-100)] [帧数上限]"
echo -e "${YELLOW}参数说明:${NC}"
echo -e "  帧率: 可选，默认24fps（建议24-30）"
echo -e "  宽度: 可选，默认800px（高度自动按比例计算）"
echo -e "  质量: 可选，默认80（0-100，值越高质量越好）"
echo -e "  帧数上限: 可选，默认0（表示无限制）"
echo -e "${YELLOW}示例:${NC} ./$0 input.mp4 output.webp 00:01:00 00:00:10 30 1080 90"
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
DURATION="$4"  # 格式为 HH:MM:SS 或 MM:SS 或 SS

# 针对Git Bash环境的特殊处理
if [[ $(uname -a) =~ Msys || $(uname -a) =~ mingw ]]; then
    # 在Git Bash中，将路径转换为Windows格式并确保特殊字符正确处理
    INPUT_FILE=$(cygpath -w "$INPUT_FILE" 2>/dev/null || echo "$INPUT_FILE")
    OUTPUT_FILE=$(cygpath -w "$OUTPUT_FILE" 2>/dev/null || echo "$OUTPUT_FILE")
fi

# 强制检查输出文件扩展名
if [[ ! "$OUTPUT_FILE" =~ \.webp$ ]]; then
    echo -e "${RED}错误：输出文件必须以.webp为扩展名${NC}"
    exit 1
fi

# WebP处理参数
FPS=${5:-24}
WIDTH=${6:-800}
QUALITY=${7:-80}
INTERPOLATION="lanczos"
MAX_FRAMES_CAP=${8:-0}  # 帧数上限，0表示无限制
COMPRESSION_LEVEL=6

# 校验质量参数范围
if ! [[ "$QUALITY" =~ ^[0-9]+$ ]] || [ "$QUALITY" -lt 0 ] || [ "$QUALITY" -gt 100 ]; then
    echo -e "${RED}错误：质量参数必须是0-100之间的整数${NC}"
    exit 1
fi

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

# 如果设置了帧数上限且大于0，则与计算的帧数比较取最小值
if [ "$MAX_FRAMES_CAP" -gt 0 ]; then
    MAX_FRAMES=$(( CALCULATED_FRAMES > MAX_FRAMES_CAP ? MAX_FRAMES_CAP : CALCULATED_FRAMES ))
else
    MAX_FRAMES=$CALCULATED_FRAMES
fi

# 输出参数信息（包含动态计算的帧数）
echo -e "${GREEN}开始处理视频:${NC} $INPUT_FILE"
echo -e "${GREEN}输出WebP:${NC} $OUTPUT_FILE"
echo -e "${GREEN}参数:${NC} 开始=$START_TIME, 时长=$DURATION($DURATION_SECONDS秒), 帧率=$FPS, 宽度=$WIDTH, 质量=$QUALITY"
if [ "$MAX_FRAMES_CAP" -gt 0 ]; then
    echo -e "${GREEN}帧数控制:${NC} 计算所需帧数=$CALCULATED_FRAMES, 实际使用帧数=$MAX_FRAMES（上限=$MAX_FRAMES_CAP）"
else
    echo -e "${GREEN}帧数控制:${NC} 计算所需帧数=$CALCULATED_FRAMES, 实际使用帧数=$MAX_FRAMES（无限制）"
fi

# 检查输入视频分辨率
RESOLUTION=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$INPUT_FILE")
echo -e "${YELLOW}源视频分辨率:${NC} $RESOLUTION"

# 视频处理滤镜链（优化人物细节和兼容性）
# 极低的降噪参数，最大程度保留人物面部和身体细节
# 轻微的锐化，保持自然效果
# 适度的色彩调整，提高亮度和对比度
FILTER_CHAIN="\
fps=$FPS,\
hqdn3d=0.3:0.2:0.8:0.6,\
unsharp=3:3:0.4:3:3:0.3,\
eq=contrast=1.01:brightness=0.02:saturation=1.02,\
scale=${WIDTH}:-1:flags=$INTERPOLATION,\
select='lt(n,$MAX_FRAMES)',\
setpts=N/$FPS/TB"

# 核心转换命令
echo -e "${YELLOW}正在生成WebP动图...${NC}"
ffmpeg -y \
  -ss "$START_TIME" -t "$DURATION" \
  -i "$INPUT_FILE" \
  -vf "$FILTER_CHAIN" \
  -c:v libwebp \
  -loop 0 \
  -qscale:v "$QUALITY" \
  -compression_level "$COMPRESSION_LEVEL" \
  -preset default \
  -an \
  -safe 0 \
  "$OUTPUT_FILE" || { echo -e "${RED}生成WebP失败${NC}"; exit 1; }

echo -e "${GREEN}处理完成!${NC}"
echo -e "${GREEN}文件位置:${NC} $OUTPUT_FILE"




# 1. 参数体系调整
# ◦ 新增QUALITY参数（0-100）：WebP 的核心质量控制，默认 80（兼顾质量与体积），100 接近无损
# ◦ 提高默认帧率至 24fps：WebP 对高帧率支持更好，24-30fps 可显著提升流畅度
# ◦ 增加COMPRESSION_LEVEL（0-6）：控制编码复杂度，6 为质量与速度的平衡值
# ◦ 放宽MAX_FRAMES至 150：WebP 的帧压缩效率高于 GIF，可容纳更多帧
# 2. 滤镜优化
# ◦ 降噪参数更保守（hqdn3d值降低）：WebP 对细节保留能力更强，避免过度降噪丢失信息
# ◦ 色彩调整更轻微：WebP 色彩空间更广，无需激进增强即可呈现丰富色彩
# ◦ 锐化强度降低：避免高频细节过多导致 WebP 压缩效率下降
# 3. 编码特性适配
# ◦ 使用专用编码器libwebp：比通用编码器更优化 WebP 格式
# ◦ 添加-preset default：针对照片类内容优化编码策略（可选photo/text）
# ◦ 明确移除音频-an：WebP 动图不支持音频，减少无效处理
# 4. 使用建议：
# • 追求极致质量：QUALITY=100 + COMPRESSION_LEVEL=6（文件较大，适合高质量展示）
# • 平衡体积与质量：QUALITY=70-80（默认值，大多数场景推荐）
# • 小体积需求：QUALITY=50-60 + COMPRESSION_LEVEL=6（牺牲少量细节换取体积）
# • 高动态场景（如快速运动）：提高帧率至 30fps，确保流畅度
# WebP 相比 GIF 的优势：相同质量下体积小 30-50%，支持更多色彩和透明效果，是现代 Web 环境的更优选择。

# 使用：./gifDuceNewHuman.sh "input.mp4" "output.webp" 00:01:00 00:00:10 30 1080 100

# 方案二：在PowerShell中直接使用FFmpeg命令（Windows环境下使用）
# 替换以下参数：
#   <INPUT_FILE>: 输入视频文件路径
#   <OUTPUT_FILE>: 输出WebP文件路径
#   <START_TIME>: 开始时间，格式：HH:MM:SS
#   <DURATION>: 持续时间，格式：HH:MM:SS
#   <FPS>: 帧率
#   <WIDTH>: 输出宽度
#   <QUALITY>: 质量（0-100）
#   <COMPRESSION_LEVEL>: 压缩级别（0-6）
#ffmpeg -y -ss <START_TIME> -t <DURATION> -i "<INPUT_FILE>" -vf "fps=<FPS>,hqdn3d=0.3:0.2:0.8:0.6,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02,scale=<WIDTH>:-1:flags=lanczos,setpts=N/<FPS>/TB" -c:v libwebp -loop 0 -qscale:v <QUALITY> -compression_level <COMPRESSION_LEVEL> -preset default -an "<OUTPUT_FILE>"

# 示例：
#ffmpeg -y -ss 00:09:00 -t 00:00:05 -i "朗读者.1080p.BD中英双字.mp4" -vf "fps=25,hqdn3d=0.3:0.2:0.8:0.6,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02,scale=720:-1:flags=lanczos,setpts=N/25/TB" -c:v libwebp -loop 0 -qscale:v 90 -compression_level 6 -preset default -an "朗读者.1080p.BD中英双字.webp"