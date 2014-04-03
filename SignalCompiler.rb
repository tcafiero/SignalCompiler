#require 'rubygems'
require 'json'
require 'pp'

timescale=[]
lastitem=[]
node=Hash.new
TIMER75MSEC=75.0/1000.0

json = File.read(ARGV[0]+'.json')
pattern = JSON.parse(json)
tic=0

vfname=pattern["head"]["text"]
testFileName=ARGV[0]+"Test.prc"
testFile=File.open(testFileName, 'w')

string=pattern["foot"]["text"]
field=string.split
case
when field[2] == "msec"
  tick=field[1].to_i
when field[2] == "sec"
  tick=field[1].to_i*1000
when field[2] == "min"
  tick=field[1].to_i*1000*60
when field[2] == "hour"
  tick=field[1].to_i*1000*60*60
end

signal=pattern["signal"]
##pp signal
signal.each do | block |
  if block.kind_of?(Array)
    block.each  do| track|
      if track.kind_of?(String)
        type=track
      else
        track["vector"]=[]
        v=track["vector"]
        track.each  do |key, value|
          if key == "node"
            index=0
            value.each_char do | char |
              if char != '.'
                node[char]=index
              end
              index += 1
            end
          end
          if key == "wave"
            index=0
            v[0]=[]
            value.each_char do | char |
              case
              when char == "p" || char == "P"
                v.last << [1,0]
              when char == "n" || char == "N"
                v.last << [0,1]
              when char == "0"
                v.last << [0,0]
              when char == "1"
                v.last << [1,1]
              when char == "x"
                v.last << [-1, -1]
              when char == "."
                if v.last.any?
                  v.last << v.last.last
                else
                  if v.any?
                    v.last << v[-3][-1]
                  end
                end
              when char == "=" || char == "2" || char == "3" || char == "4" || char == "5"
                data=track["data"].shift
                v.last << [data.to_i, data.to_i]
              when char == "|"
                v << ["gap"]
                v << []
              end
            end
          end
        end
      end
    end
  end
end
#pp pattern
#pp node

gap = Hash.new
edge=pattern["edge"]
edge.each do | string|
  string.scan(/(\w)~->(\w)\s+(\d+)\s*(\w+)/).collect { |ref1, ref2, value, timebase| gap[ref1]=[ref2, value, timebase]}
end
#pp gap

foot=pattern["foot"]
foot["text"].scan(/tick: (\d+)\s*(\w+)/).collect {|value, scale|timescale=[value, scale]}
#pp timescale

gap.each_key do |key|
  case
  when gap[key][2].casecmp("sec") == 0
    gap[key][1] = gap[key][1].to_i*1000
    gap[key][2] = "msec"
  end
end
#pp gap

if timescale[1].casecmp("sec") == 0
  timescale[0] = timescale[0].to_i * 1000
  timescale[1] = "msec"
end
#pp timescale

gaplen=[]
gap.each_key do |key|
  point=gap[key][0]
  timediff=gap[key][1]
  ticdiff=timediff/timescale[0].to_i
  gaplen<<ticdiff-(node[point]-node[key])+1
end
#pp gaplen

signal.each do | block |
  if block.kind_of?(Array)
    block.each  do| track|
      if track.kind_of?(String)
        type=track
      else
        value=track["vector"]
        k=0
        value.each do |segment|
          if segment[0].kind_of?(String)
            if segment[0].casecmp("gap") == 0
              segment.delete_at(0)
              segment << lastitem * gaplen[k]
              k += 1
            end
          end
          lastitem=segment.last
        end
      end
    end
  end
end

#pp pattern
wave={}
testPattern = Hash.new
signal.each do | block |
  if block.kind_of?(Array)
    block.each  do| track|
      if track.kind_of?(String)
        testPattern[track] = Hash.new
        wave=testPattern[track]
      else
        wave[track["name"]]=value=track["vector"].flatten
      end
    end
  end
end
##pp testPattern

event=Hash.new
testPattern.each_pair do | blockname, block |
  block.each_pair  do| trackname, track|
    lastValue=-1
    tic=0
    track.each do | value |
      if value != lastValue
        if event[tic].nil?
          event[tic]=Array.new
        end
        event[tic] << [blockname, trackname, value]
        lastValue=value
      end
      tic += 1
    end
  end
end
##pp event.keys.sort

scale=timescale[0]/2/1000.0/TIMER75MSEC
previousTime=0.0
testFile.puts "SET RADIX /DECIMAL"
testFile.puts "enter VF048_StopWatch=0"

event.keys.sort.each do | time|
  array=event[time]
  testFile.puts "while VF048_StopWatch > 0"
  testFile.puts "endw"
  n_events=0
  array.each do | action |
    if action[2] != -1
      if action[0].casecmp("Input") == 0
        testFile.puts "enter "+vfname+"_ModelInputs."+action[1]+"="+action[2].to_s
        n_events += 1
      end
    end
  end
  if n_events > 0
    testFile.puts "enter "+vfname+"_ModelEventCounter="+n_events.to_s
  end
  condition=""
  operator=""
  array.each do | action |
    if action[2] != -1
      if action[0].casecmp("Output") == 0
        condition += operator+" ("+vfname+"_ModelOutputs."+action[1]+" == "+action[2].to_s+") "
        operator="&&"
      end
    end
  end
  if condition != ""
    testFile.puts "if ("+condition+")"
    testFile.puts "printf \"OK\\n\""
    testFile.puts "else"
    testFile.puts "printf \"ERROR\\n\""
    testFile.puts "endif"
  end
  testFile.puts "enter VF048_StopWatch="+(((time-previousTime)*scale).to_i).to_s
  previousTime=time

  #  t=(((time-previousTime)*timescale[0]/1000.0)/TIMER75MSEC).to_i
  #  testFile.puts "enter VF048_StopWatch="+t.to_s
end
testFile.close
