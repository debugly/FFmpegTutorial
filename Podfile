# FFmpeg Version

FF_3_4_7='3.4.7'
FF_4_2_2='4.2.2'

# use_frameworks!
platform :ios,'8.0'

workspace 'StudyFFmpeg.xcworkspace'

def Pod_Spec(prjo,name,spec,path)
  
    project "#{path}#{prjo}/#{prjo}.xcodeproj"
    pod "#{name}", :podspec => "https://raw.githubusercontent.com/debugly/MRFFToolChainPod/master/#{spec}.podspec"
end


def Pod_Target(t,name,spec,path='')
  
  puts("Target:#{t} will use #{spec}")
  target t do
      Pod_Spec(t,name,spec,path)
  end
  
end


def Pod_FF_Target(t,v=FF_3_4_7)
  
  Pod_Target(t,'MRFFmpegPod',"MRFFmpeg#{v}")
  
end


def line(c)
  if c >= 0 then
    arr = Array.new(c) {
      '-'
    }
    puts(arr.join(''))
  end
end

line(40)
Pod_FF_Target('FFmpeg001')
line(16)
Pod_FF_Target('FFmpeg002')
line(16)
Pod_FF_Target('FFmpeg003')
line(16)
Pod_FF_Target('FFmpeg004')
line(16)
Pod_FF_Target('FFmpeg005')
line(16)
Pod_FF_Target('FFmpeg006')
line(16)
Pod_FF_Target('FFmpeg006-1')
line(16)
Pod_FF_Target('FFmpeg007')
line(16)
Pod_FF_Target('FFmpeg008')
line(16)
Pod_FF_Target('FFmpeg009')
line(40)
line(0)
line(40)
Pod_Target('Mp3Encoder','MRLamePod','MRLamePod3.100','Lame/')
line(40)

