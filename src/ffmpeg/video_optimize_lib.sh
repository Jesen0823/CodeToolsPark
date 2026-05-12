#!/bin/bash
# 视频转动态图优化库 - 摄影光学与色彩学优化
# 提供人像肤色、细节、流畅度的高保真处理

# 色彩空间定义
declare -A COLORSPACES=(
    [bt709]="bt709"           # 高清视频标准（推荐用于人像）
    [bt601]="bt601"           # 标清视频标准
    [srgb]="srgb"             # sRGB色彩空间
)

# 降噪预设（保留细节程度）
declare -A DENOISE_PRESETS=(
    [minimal]="0.2:0.1:0.5:0.3"      # 最小降噪，保留所有细节
    [light]="0.3:0.2:0.8:0.6"        # 轻度降噪（推荐人像）
    [moderate]="0.5:0.3:1.0:0.8"     # 中度降噪
    [strong]="0.8:0.5:1.5:1.0"       # 强降噪
)

# 锐化预设（细节恢复程度）
declare -A SHARPEN_PRESETS=(
    [subtle]="3:3:0.3:2:2:0.2"       # 细微锐化
    [normal]="5:5:0.8:3:3:0.4"       # 标准锐化（推荐人像）
    [strong]="7:7:1.2:4:4:0.6"       # 强锐化
    [extreme]="9:9:1.5:5:5:0.8"      # 极端锐化
)

# 色彩增强预设
declare -A COLOR_PRESETS=(
    [natural]="contrast=1.01:brightness=0.01:saturation=1.02"
    [portrait]="contrast=1.02:brightness=0.01:saturation=1.08"  # 人像优化
    [vivid]="contrast=1.05:brightness=0.02:saturation=1.15"
    [cinema]="contrast=1.03:brightness=-0.02:saturation=1.10"
)

# 获取视频信息
get_video_info() {
    local input_file="$1"
    if [ ! -f "$input_file" ]; then
        echo "错误：文件不存在 $input_file" >&2
        return 1
    fi

    ffprobe -v error -select_streams v:0 \
        -show_entries stream=width,height,r_frame_rate,duration \
        -of csv=s=x:p=0 "$input_file"
}

# 计算最优帧率（基于源视频）
calculate_optimal_fps() {
    local source_fps="$1"
    local target_fps="${2:-30}"

    # 如果源视频帧率低于目标，使用源帧率
    if (( $(echo "$source_fps < $target_fps" | bc -l) )); then
        echo "$source_fps"
    else
        echo "$target_fps"
    fi
}

# 计算最优宽度（基于源视频分辨率）
calculate_optimal_width() {
    local source_width="$1"
    local target_width="${2:-1080}"

    # 如果源视频宽度低于目标，使用源宽度
    if [ "$source_width" -lt "$target_width" ]; then
        echo "$source_width"
    else
        echo "$target_width"
    fi
}

# 生成GIF优化滤镜链
generate_gif_filter() {
    local fps="$1"
    local width="$2"
    local denoise_preset="${3:-light}"
    local sharpen_preset="${4:-normal}"
    local color_preset="${5:-portrait}"
    local colorspace="${6:-bt709}"

    local denoise="${DENOISE_PRESETS[$denoise_preset]}"
    local sharpen="${SHARPEN_PRESETS[$sharpen_preset]}"
    local color="${COLOR_PRESETS[$color_preset]}"

    echo "fps=$fps,hqdn3d=$denoise,colorspace=$colorspace,unsharp=$sharpen,eq=$color,scale=$width:-1:flags=lanczos"
}

# 生成APNG优化滤镜链
generate_apng_filter() {
    local fps="$1"
    local width="$2"
    local denoise_preset="${3:-light}"
    local sharpen_preset="${4:-normal}"
    local color_preset="${5:-portrait}"
    local colorspace="${6:-bt709}"
    local max_frames="${7:-0}"

    local denoise="${DENOISE_PRESETS[$denoise_preset]}"
    local sharpen="${SHARPEN_PRESETS[$sharpen_preset]}"
    local color="${COLOR_PRESETS[$color_preset]}"

    if [ "$max_frames" -gt 0 ]; then
        echo "fps=$fps,hqdn3d=$denoise,colorspace=$colorspace,unsharp=$sharpen,eq=$color,scale=$width:-1:flags=lanczos,select='lt(n,$max_frames)',setpts=N/$fps/TB"
    else
        echo "fps=$fps,hqdn3d=$denoise,colorspace=$colorspace,unsharp=$sharpen,eq=$color,scale=$width:-1:flags=lanczos,setpts=N/$fps/TB"
    fi
}

# 生成WebP优化滤镜链
generate_webp_filter() {
    local fps="$1"
    local width="$2"
    local denoise_preset="${3:-light}"
    local sharpen_preset="${4:-normal}"
    local color_preset="${5:-portrait}"
    local colorspace="${6:-bt709}"
    local max_frames="${7:-0}"

    local denoise="${DENOISE_PRESETS[$denoise_preset]}"
    local sharpen="${SHARPEN_PRESETS[$sharpen_preset]}"
    local color="${COLOR_PRESETS[$color_preset]}"

    if [ "$max_frames" -gt 0 ]; then
        echo "fps=$fps,hqdn3d=$denoise,colorspace=$colorspace,unsharp=$sharpen,eq=$color,scale=$width:-1:flags=lanczos,select='lt(n,$max_frames)',setpts=N/$fps/TB"
    else
        echo "fps=$fps,hqdn3d=$denoise,colorspace=$colorspace,unsharp=$sharpen,eq=$color,scale=$width:-1:flags=lanczos,setpts=N/$fps/TB"
    fi
}

# 估算输出文件大小（基于参数）
estimate_file_size() {
    local format="$1"
    local fps="$2"
    local width="$3"
    local duration_seconds="$4"
    local quality="${5:-80}"

    local pixels=$((width * width * 9 / 16))  # 假设16:9宽高比
    local total_pixels=$((pixels * fps * duration_seconds))

    case "$format" in
        gif)
            # GIF: 约2字节/像素（256色+抖动）
            echo $((total_pixels * 2 / 1024 / 1024))
            ;;
        apng)
            # APNG: 约1.5字节/像素（24位真彩+压缩）
            echo $((total_pixels * 15 / 10 / 1024 / 1024))
            ;;
        webp)
            # WebP: 质量相关，约0.5-1字节/像素
            local bytes_per_pixel=$((100 - quality))
            bytes_per_pixel=$((bytes_per_pixel / 100 + 1))
            echo $((total_pixels * bytes_per_pixel / 1024 / 1024))
            ;;
        *)
            echo "0"
            ;;
    esac
}

# 打印优化建议
print_optimization_tips() {
    local format="$1"
    local file_size_mb="$2"

    echo "=== 优化建议 ==="

    case "$format" in
        gif)
            if [ "$file_size_mb" -gt 5 ]; then
                echo "⚠ GIF文件较大（${file_size_mb}MB）"
                echo "  建议：降低帧率（15-20fps）或宽度（640-800px）"
            fi
            echo "✓ GIF优势：兼容性最好，支持透明"
            echo "✗ GIF劣势：256色限制，肤色渐变可能损失"
            ;;
        apng)
            echo "✓ APNG优势：24位真彩，肤色细节保留最好"
            echo "✗ APNG劣势：浏览器支持不如GIF"
            if [ "$file_size_mb" -gt 10 ]; then
                echo "⚠ 文件较大，考虑提高压缩级别（7-9）"
            fi
            ;;
        webp)
            echo "✓ WebP优势：压缩效率最高，文件最小"
            echo "✗ WebP劣势：某些旧浏览器不支持"
            if [ "$file_size_mb" -gt 3 ]; then
                echo "⚠ 文件较大，考虑降低质量（70-80）"
            fi
            ;;
    esac
}

# 导出函数供外部脚本使用
export -f get_video_info
export -f calculate_optimal_fps
export -f calculate_optimal_width
export -f generate_gif_filter
export -f generate_apng_filter
export -f generate_webp_filter
export -f estimate_file_size
export -f print_optimization_tips
