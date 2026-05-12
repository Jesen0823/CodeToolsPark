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
echo -e "${YELLOW}使用方法:${NC} ./$0 输入视频 输出APNG(必须带.apng扩展名) 开始时间 持续时间 [帧率] [宽度] [压缩级别] [qualityFirst]"
echo -e "${YELLOW}参数说明:${NC}"
echo -e "  帧率: 可选，默认30fps（建议15-30）"
echo -e "  宽度: 可选，默认1080px（高度自动按比例计算）"
echo -e "  压缩级别: 可选，默认5（0-9，值越高压缩率越高）"
echo -e "  qualityFirst: 可选，true/1=质量优先（色彩极致还原），默认false（平衡模式）"
echo -e "${YELLOW}示例:${NC}"
echo -e "  平衡模式: ./$0 input.mp4 output.apng 00:01:00 00:00:10 30 1080 5"
echo -e "  质量优先: ./$0 input.mp4 output.apng 00:01:00 00:00:10 30 1080 3 true"
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

# 强制检查输出文件扩展名
if [[ "$OUTPUT_FILE" != *.apng ]]; then
    echo -e "${RED}错误：输出文件必须以.apng为扩展名${NC}"
    exit 1
fi

# 视频处理参数（支持用户自定义）
FPS=${5:-30}                  # 第5参数：帧率，默认30（APNG支持高帧率，流畅度更好）
WIDTH=${6:-1080}              # 第6参数：宽度，默认1080px（APNG支持高分辨率，细节更清晰）
COMPRESSION_LEVEL=${7:-5}     # 第7参数：压缩级别，默认5（平衡质量与文件大小）
QUALITY_FIRST="${8:-false}"   # 第8参数：质量优先模式开关，默认false（平衡模式）
MAX_FRAMES_CAP=0              # 帧数上限，0表示无限制
INTERPOLATION="lanczos"       # 高质量缩放算法
COLORSPACE="bt709"            # 色彩空间（BT.709用于高清视频，肤色准确）

# 根据质量优先模式调整参数
if [[ "$QUALITY_FIRST" == "true" || "$QUALITY_FIRST" == "1" ]]; then
    # 质量优先模式：极致色彩还原，肤色自然饱满
    DENOISE_PARAMS="0.2:0.1:0.5:0.3"      # 最小降噪，保留所有细节
    SHARPEN_PARAMS="7:7:1.2:4:4:0.6"      # 强锐化，细节清晰
    COLOR_PARAMS="contrast=1.03:brightness=0.01:saturation=1.12"  # 饱和度提升12%，肤色饱满
    COMPRESSION_LEVEL=3                    # 降低压缩级别，优先质量
    QUALITY_MODE="质量优先（极致还原）"
else
    # 平衡模式：压缩与质量平衡（默认）
    DENOISE_PARAMS="0.3:0.2:0.8:0.6"      # 轻度降噪
    SHARPEN_PARAMS="5:5:0.8:3:3:0.4"      # 标准锐化
    COLOR_PARAMS="contrast=1.02:brightness=0.01:saturation=1.08"  # 适度饱和度
    # COMPRESSION_LEVEL 使用用户指定的值
    QUALITY_MODE="平衡模式（压缩优先）"
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

# 校验压缩级别范围（0-9）
if ! [[ "$COMPRESSION_LEVEL" =~ ^[0-9]$ ]]; then
    echo -e "${RED}错误：压缩级别必须是0-9之间的整数${NC}"
    exit 1
fi

echo -e "${GREEN}开始处理视频:${NC} $INPUT_FILE"
echo -e "${GREEN}输出APNG:${NC} $OUTPUT_FILE"
echo -e "${GREEN}参数:${NC} 开始=$START_TIME, 时长=$DURATION($DURATION_SECONDS秒), 帧率=$FPS, 宽度=$WIDTH, 压缩级别=$COMPRESSION_LEVEL"
echo -e "${GREEN}模式:${NC} $QUALITY_MODE"
if [ "$MAX_FRAMES_CAP" -gt 0 ]; then
    echo -e "${GREEN}帧数控制:${NC} 计算所需帧数=$CALCULATED_FRAMES, 实际使用帧数=$MAX_FRAMES（上限=$MAX_FRAMES_CAP）"
else
    echo -e "${GREEN}帧数控制:${NC} 计算所需帧数=$CALCULATED_FRAMES, 实际使用帧数=$MAX_FRAMES（无限制）"
fi

# 检查输入视频分辨率
RESOLUTION=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$INPUT_FILE")
echo -e "${YELLOW}源视频分辨率:${NC} $RESOLUTION"

# 视频处理滤镜链（人像肤色与细节优化）
# 根据质量模式调整参数
# 质量优先：最小降噪、强锐化、高饱和度
# 平衡模式：轻度降噪、标准锐化、适度饱和度
FILTER_CHAIN="fps=$FPS,\
hqdn3d=$DENOISE_PARAMS,\
colorspace=$COLORSPACE,\
unsharp=$SHARPEN_PARAMS,\
eq=$COLOR_PARAMS,\
scale=${WIDTH}:-1:flags=$INTERPOLATION,\
select='lt(n,$MAX_FRAMES)',\
setpts=N/$FPS/TB"

# 核心转换命令 - APNG编码优化
echo -e "${YELLOW}正在生成APNG动图...${NC}"
ffmpeg -y \
  -ss "$START_TIME" -t "$DURATION" \
  -i "$INPUT_FILE" \
  -vf "$FILTER_CHAIN" \
  -c:v apng \
  -compression_level "$COMPRESSION_LEVEL" \
  -plays 0 \
  -pred mixed \
  -f apng \
  -safe 0 \
  "$OUTPUT_FILE" || { echo -e "${RED}生成APNG失败${NC}"; exit 1; }

echo -e "${GREEN}处理完成!${NC}"
echo -e "${GREEN}文件位置:${NC} $OUTPUT_FILE"


# 1. 参数优化
### 帧率默认值提高到 24fps（APNG 对高帧率支持更好，画面更流畅）
### 默认宽度提高到 800px（APNG 在高分辨率下色彩损失更小）
### 新增compression_level参数（0-9），3 为平衡值（质量接近无损，文件大小可控）
### 加入limit_frames限制最大帧数（避免长时长转换导致文件过大）
# 3. 滤镜调整
### 降噪参数更保守（hqdn3d值降低），保留更多细节
### 增强色彩微调（eq滤镜提高对比度和饱和度），让 APNG 的色彩优势更明显
### 保留高质量缩放算法（lanczos）和锐化滤镜，维持画面清晰度
# 4. 编码设置
### 使用 APNG 专用编码器-c:v apng
### 强制循环播放（-plays 0），与原 GIF 脚本行为一致
### 明确指定输出格式-f apng，确保编码器正确识别
#
# 优势
### 色彩保真：24 位真彩色远超 GIF 的 256 色限制，渐变和复杂色彩更细腻
### 画面流畅：支持更高帧率（建议 24-30fps），运动画面更自然
### 透明保留：如需透明通道，可在滤镜链中添加alphaextract等处理（原视频需带透明通道）
### 质量可控：通过compression_level平衡质量和文件大小（数值越高压缩率越高，建议 3-5）

# 将compression_level作为第 7 个可选参数，通过${7:-0}实现 “默认 0，用户输入优先” 的逻辑,推荐3较为平衡。

# 使用示例：
### 默认压缩级别（3）：./video2apng.sh "input.mp4" "output.apng" 00:00:00 00:00:05 30 1080
### 自定义帧率、宽度、压缩级别：./video2apng.sh input.mp4 output.apng 00:00:00 00:00:05 30 1080 6（30fps，1080px 宽，压缩级别 6）

# 方案二：在PowerShell中直接使用FFmpeg命令（Windows环境下使用）
# 替换以下参数：
#   <INPUT_FILE>: 输入视频文件路径
#   <OUTPUT_FILE>: 输出APNG文件路径
#   <START_TIME>: 开始时间，格式：HH:MM:SS
#   <DURATION>: 持续时间，格式：HH:MM:SS
#   <FPS>: 帧率
#   <WIDTH>: 输出宽度
#   <COMPRESSION_LEVEL>: 压缩级别（0-9）
#ffmpeg -y -ss <START_TIME> -t <DURATION> -i "<INPUT_FILE>" -vf "fps=<FPS>,hqdn3d=0.3:0.2:0.8:0.6,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02,scale=<WIDTH>:-1:flags=lanczos,setpts=N/<FPS>/TB" -c:v apng -compression_level <COMPRESSION_LEVEL> -plays 0 -pred mixed -f apng "<OUTPUT_FILE>"

# 示例：
#ffmpeg -y -ss 00:09:00 -t 00:00:05 -i "朗读者.1080p.BD中英双字.mp4" -vf "fps=25,hqdn3d=0.3:0.2:0.8:0.6,unsharp=3:3:0.4:3:3:0.3,eq=contrast=1.01:brightness=0.02:saturation=1.02,scale=720:-1:flags=lanczos,setpts=N/25/TB" -c:v apng -compression_level 7 -plays 0 -pred mixed -f apng "朗读者.1080p.BD中英双字-001.apng"
