# https://wizyoung.dogcraft.xyz/video2gif-with-high-quality
set -e

# global filter
fps=15
scale=480:-1
interpolation=lanczos

if [ $5 != 0 ]
then 
	fps=$5
fi

if [ $6 != 0 ]
then 
	scale=$6:-1
fi
printf "the thired param :->-> %d \n" $fps

# for palettegen
max_colors=256  # up to 256
reserve_transparent=on
stats_mode=diff  # chosen from [full, diff, single]

# for paletteuse
dither=bayer  # chosen from [bayer, heckbert, floyd_steinberg, sierra2, sierra2_4a, none]
bayer_scale=3  # [0, 5]. only works when dither=bayer. higher means more color banding but less crosshatch pattern and smaller file size
diff_mode=rectangle  # chosen from [rectangle, none]
new=on  # when stats_mode=single and new=on, each frame uses different palette

ffmpeg -ss $3 -t $4 -i $1 -vf "fps=$fps,scale=$scale:flags=$interpolation,split[split1][split2];[split1]palettegen=max_colors=$max_colors:reserve_transparent=$reserve_transparent:stats_mode=$stats_mode[pal];[split2][pal]paletteuse=dither=$dither:bayer_scale=$bayer_scale:diff_mode=$diff_mode:new=$new" -y $2
# use example: 输入|输出|起始点|时长|fps|width
# > ./gifDuce.sh input.mp4 output.gif 00:06:44 00:00:14  10  960
# ./gifDuce.sh "input.mp4" "out-1.gif" 00:00:00 00:00:05  15  360
# 天文爱好者Jesen.#
