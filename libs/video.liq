# Width for all video frames.
# @category Source / Video Processing
def video.frame.width() =
  get(default=-1,"frame.video.width")
end

# Height for all video frames.
# @category Source / Video Processing
def video.frame.height() =
  get(default=-1,"frame.video.height")
end

# Rate for all video frames.
# @category Source / Video Processing
def video.frame.rate() =
  get(default=-1,"frame.video.samplerate")
end

# Add a static image on the first video channel.
# @category Source / Video Processing
# @param ~id Force the value of the source ID.
# @param ~width Scale to width (negative means original width).
# @param ~height Scale to height (negative means original height).
# @param ~x x position.
# @param ~y y position.
# @param ~file Path to the image file.
def video.add_image(~id="", ~width=int_getter(-1), ~height=int_getter(-1), ~x=int_getter(max_int()), ~y=int_getter(max_int()), ~file, s)
  image = single(id=id, file)
  image = video.resize(id=id, x=x, y=y, width=width, height=height, image)
  image = mux_audio(audio=blank(), image)
  add([s,image])
end

# Input from ffmpeg.
# @category Source / Video Processing
# @flag extra
# @param ~restart restart on exit.
# @param ~restart_on_error restart on exit with error.
# @param ~buffer Duration of the pre-buffered data.
# @param ~max Maximum duration of the buffered data.
# @param input ffmpeg options specifying the input
def input.external.ffmpeg(~id="input.external.ffmpeg", ~show_command=false,
                          ~restart=true,~restart_on_error=false,
                          ~buffer=0.2,~max=10.,input)
  input = (input : string)
  ffmpeg = get(default="ffmpeg#{exe_ext}","decoder.external.ffmpeg.path")
  cmd = "#{ffmpeg} #{input} -f avi \
         -vf \"scale=#{video.frame.width()}:#{video.frame.height()}:\
               force_original_aspect_ratio=decrease,pad=#{video.frame.width()}:\
               #{video.frame.height()}:(ow-iw)/2:(oh-ih)/2\",\
               format=yuv420p,fps=fps=#{video.frame.rate()} \
         -c:v rawvideo -r #{video.frame.rate()} -c:a pcm_s16le -ac 2 \
         -ar #{audio.samplerate()} pipe:1"

  if show_command then log.important(label=id, "command: #{cmd}") end

  (input.external.avi(id=id,restart=restart,
                      restart_on_error=restart_on_error,
                      buffer=buffer,max=max,cmd):source(audio=2,video=1,midi=0))
end

# ffmpeg's test source video (useful for testing and debugging).
# @param ~restart restart on exit.
# @param ~restart_on_error restart on exit with error.
# @param ~buffer Duration of the pre-buffered data.
# @param ~max Maximum duration of the buffered data.
# @category Source / Video Processing
# @flag extra
def video.external.testsrc(~id="video.external.testsrc",~restart=true,~restart_on_error=false,~buffer=0.2,~max=10.,~framerate=0)
  framerate = if framerate <= 0 then video.frame.rate() else framerate end
  cmd = "-f lavfi -i testsrc=size=#{video.frame.width()}x#{video.frame.height()}:rate=#{framerate} \
         -f lavfi -i sine=frequency=440:beep_factor=2:sample_rate=#{audio.samplerate()}"

  input.external.ffmpeg(id=id,restart=restart,
                        restart_on_error=restart_on_error,
                        buffer=buffer,max=max,show_command=true,cmd)
end

# Output to ffmpeg.
# @category Output
# @flag extra
# @param ~id Force the value of the source ID.
# @param ~fallible Allow the child source to fail, in which case the output will be (temporarily) stopped.
# @param ~flush Perform a flush after each write.
# @param ~on_start Callback executed when outputting starts.
# @param ~on_stop Callback executed when outputting stops.
# @param ~reopen_delay Prevent re-opening within that delay, in seconds.
# @param ~reopen_on_metadata Re-open on every new metadata information.
# @param ~reopen_when When should the output be re-opened.
# @param ~start Automatically start outputting whenever possible. If true, an infallible (normal) output will start outputting as soon as it is created, and a fallible output will (re)start as soon as its source becomes available for streaming.
def output.external.ffmpeg(~id="", ~show_command=false, ~flush=false, ~fallible=false, 
                           ~on_start={()}, ~on_stop={()}, ~reopen_delay=120.,
                           ~reopen_on_metadata=false, ~reopen_when={false},
                           ~start=true, output, s)
  output = (output : string)
  cmd = "ffmpeg -f avi -vcodec rawvideo -r #{video.frame.rate()} -acodec pcm_s16le -i pipe:0 #{output}"
  if show_command then log.important(label="output.external.ffmpeg", "command: #{cmd}") end
  output.external(id=id, flush=flush, fallible=fallible, on_start=on_start, on_stop=on_stop, reopen_delay=reopen_delay,
                  reopen_on_metadata=reopen_on_metadata, reopen_when=reopen_when, start=start, %avi, cmd, s)
end

# Output a HLS playlist using ffmpeg
# @category Output
# @flag extra
# @param ~id Force the value of the source ID.
# @param ~fallible Allow the child source to fail, in which case the output will be (temporarily) stopped.
# @param ~flush Perform a flush after each write.
# @param ~on_start Callback executed when outputting starts.
# @param ~on_stop Callback executed when outputting stops.
# @param ~reopen_delay Prevent re-opening within that delay, in seconds.
# @param ~reopen_on_metadata Re-open on every new metadata information.
# @param ~reopen_when When should the output be re-opened.
# @param ~start Automatically start outputting whenever possible. If true, an infallible (normal) output will start outputting as soon as it is created, and a fallible output will (re)start as soon as its source becomes available for streaming.
# @param ~playlist Playlist name
# @param ~directory Directory to write to
def output.file.hls.ffmpeg(~id="", ~flush=false, ~fallible=false,
                           ~on_start={()}, ~on_stop={()}, ~reopen_delay=120.,
                           ~reopen_on_metadata=false, ~reopen_when={false},
                           ~start=true, ~playlist="stream.m3u8", ~directory, s)
  width = video.frame.width()
  height = video.frame.height()
  directory = (directory : string)
  cmd = "-profile:v baseline -pix_fmt yuv420p -level 3.0 -s #{width}x#{height} -start_number 0 -hls_time 10 -hls_list_size 0 -f hls #{directory}/#{playlist}"
  output.external.ffmpeg(id=id, flush=flush, fallible=fallible, on_start=on_start, on_stop=on_stop, reopen_delay=reopen_delay,
                         reopen_on_metadata=reopen_on_metadata, reopen_when=reopen_when, start=start, cmd, s)
end

# Output an MPEG-DASH playlist using ffmpeg
# @category Output
# @flag extra
# @param ~id Force the value of the source ID.
# @param ~fallible Allow the child source to fail, in which case the output will be (temporarily) stopped.
# @param ~flush Perform a flush after each write.
# @param ~on_start Callback executed when outputting starts.
# @param ~on_stop Callback executed when outputting stops.
# @param ~reopen_delay Prevent re-opening within that delay, in seconds.
# @param ~reopen_on_metadata Re-open on every new metadata information.
# @param ~reopen_when When should the output be re-opened.
# @param ~start Automatically start outputting whenever possible. If true, an infallible (normal) output will start outputting as soon as it is created, and a fallible output will (re)start as soon as its source becomes available for streaming.
# @param ~playlist Playlist name
# @param ~directory Directory to write to
def output.file.dash.ffmpeg(~id="", ~flush=false, ~fallible=false,
                           ~on_start={()}, ~on_stop={()}, ~reopen_delay=120.,
                           ~reopen_on_metadata=false, ~reopen_when={false},
                           ~start=true, ~playlist="stream.mpd", ~directory, s)
  width = video.frame.width()
  height = video.frame.height()
  samplerate = audio.samplerate()
  cmd = "-map 0 -map 0 -c:a libfdk_aac -c:v libx264 -b:v:0 800k -b:v:1 300k -s:v:1 #{width}x#{height} -profile:v:1 baseline -profile:v:0 main -bf 1 -keyint_min 120 -g 120 -sc_threshold 0 -b_strategy 0 -ar:a:1 #{samplerate} -use_timeline 1 -use_template 1 -window_size 5 -adaptation_sets \"id=0,streams=v id=1,streams=a\" -f dash #{directory}/#{playlist}"
  output.external.ffmpeg(id=id, flush=flush, fallible=fallible, on_start=on_start, on_stop=on_stop, reopen_delay=reopen_delay, reopen_on_metadata=reopen_on_metadata, reopen_when=reopen_when, start=start, show_command=true, cmd, s)
end

# Stream to youtube.
# @category Output
# @flag extra
# @param ~id Force the value of the source ID.
# @param ~fallible Allow the child source to fail, in which case the output will be (temporarily) stopped.
# @param ~flush Perform a flush after each write.
# @param ~on_start Callback executed when outputting starts.
# @param ~on_stop Callback executed when outputting stops.
# @param ~reopen_delay Prevent re-opening within that delay, in seconds.
# @param ~reopen_on_metadata Re-open on every new metadata information.
# @param ~reopen_when When should the output be re-opened.
# @param ~start Automatically start outputting whenever possible. If true, an infallible (normal) output will start outputting as soon as it is created, and a fallible output will (re)start as soon as its source becomes available for streaming.
# @param ~url URL to stream to
# @param ~bitrate Bitrate of the video (in kbps)
# @param ~quality Quality of the video (low / medium / high)
# @param ~key Your secret youtube key
def output.youtube.live.ffmpeg(~id="",~flush=false, ~fallible=false,
                           ~on_start={()}, ~on_stop={()}, ~reopen_delay=120.,
                           ~reopen_on_metadata=false, ~reopen_when={false},
                           ~start=true, ~url="rtmp://a.rtmp.youtube.com/live2",
                           ~bitrate=2500,~quality="medium",~key,s)
  # Output parameters
  fps = video.frame.rate()
  samplerate = audio.samplerate()
  key = (key : string)
  cmd = "-deinterlace -vcodec libx264 -pix_fmt yuv420p -preset #{quality} -r #{fps} -g $((#{fps} * 2)) \
          -b:v #{bitrate}k -acodec libmp3lame -ar #{samplerate} -threads 6 -qscale:v 3 -b:a 712000 \
          -bufsize 512k -f flv \"#{url}/#{key}\""
  output.external.ffmpeg(id=id, flush=flush, fallible=fallible, on_start=on_start, on_stop=on_stop, reopen_delay=reopen_delay,
                         reopen_on_metadata=reopen_on_metadata, reopen_when=reopen_when, start=start, cmd, s)
end

%ifdef ffmpeg.filter.drawtext
def video.add_text.ffmpeg(~color=0xffffff, ~font="", ~size=18, ~x=10, ~y=10, text, s)
  int_args = [("fontsize", size), ("x", x), ("y", y)]
  color = "0x" ^ string.hex_of_int(pad=6, color)
  string_args = [("fontcolor", color), ("text", text)]
  string_args = if font == "" then string_args else list.add(("fontfile", font), string_args) end
  def mkfilter(graph)
    s = ffmpeg.filter.video.input(graph, s)
    s = ffmpeg.filter.drawtext(graph, int_args=int_args, string_args=string_args, s)
    ffmpeg.filter.video.output(graph, s)
  end
  ffmpeg.filter.create(mkfilter)
end
%endif

video.add_text = video.add_text.native

%ifdef video.add_text.sdl
video.add_text = video.add_text.sdl
%endif

%ifdef video.add_text.gstreamer
video.add_text = video.add_text.gstreamer
%endif

%ifdef video.add_text.gd
video.add_text = video.add_text.gd
%endif

# Display a text using the first available operator in: gd, gstreamer, sdl or native
# @param ~id Force the value of the source ID.
# @param ~color Text color (in 0xRRGGBB format).
# @param ~cycle Cycle text when it reaches left boundary.
# @param ~font Path to ttf font file.
# @param ~metadata Change text on a particular metadata (empty string means disabled).
# @param ~size Font size.
# @param ~speed Horizontal speed in pixels per second (0 means no scrolling and update \
#               according to x and y in case they are variable).
# @param ~x x offset.
# @param ~y y offset.
# @params d Text to display.
def video.add_text(~id="",~color=16777215,~cycle=true,~font="",
                   ~metadata="",~size=18,~speed=70,~x=10,~y=10,
                   d,s) =
  video.add_text(id=id,cycle=cycle,font=font,
     metadata=metadata,size=size,
     speed=speed,x=x,y=y,d,s)
end

