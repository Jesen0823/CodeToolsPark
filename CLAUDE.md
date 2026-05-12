# 项目配置说明
## 说明
- 这不是一个可执行项目，仅仅包含若干可执行shell脚本文件，可执行文件路径`CodeToolsPark\src\ffmpeg\`
- 文件`video2apng.sh`，用来将视频按指定时间，指定时长，fps, 宽度，生成apng动态图片
- 文件`video2gif.sh`，用来将视频按指定时间，指定时长，fps, 宽度，生成gif动态图片
- 文件`video2webp_stand.sh`，用来将视频按指定时间，指定时长，fps, 宽度，生成webp动态图片
- *.sh执行方式如下，各个参数分别是“[*.sh] [输入视频文件] [输出文件] [开始时间] [截取时长] [帧率] [宽度]”，根目录下：`./src/ffmpeg/video2gif.sh "./test/input.mp4" "./test/out-1.gif" 00:00:00 00:00:05  15  360`
- 代码规范，健壮

- 遵循shell脚本多平台兼容性，安全校验
- 注释准确详尽
- *.sh脚本的执行基于ffmpeg环境变量

## ffmpeg配置
- ffmpeg安装目录`F:\Program Files\ffmpeg-7.1.1-essentials_build\bin`

## 常用命令
- 执行`video2apng.sh`示例：`./video2apng.sh input.mp4 output.apng 00:00:00 00:00:05 30 1080 6`
- 执行`video2gif.sh`示例：`./video2gif.sh "input.mp4" "out-1.gif" 00:00:00 00:00:05  15  360`
- 运行`video2webp_stand.sh`示例：`./video2webp_stand.sh "input.mp4" "output.webp" 00:01:00 00:00:10 30 1080 100`

