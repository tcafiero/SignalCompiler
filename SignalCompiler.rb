#require 'rubygems'
require 'json'
require 'pp'

timescale=[]
lastitem=[]
node=Hash.new

json = File.read('prova1.json')
pattern = JSON.parse(json)

vfname=pattern["head"]["text"]

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

signal.each do | block |
  if block.kind_of?(Array)
    block.each  do| track|
      if track.kind_of?(String)
        type=track
      else
        value=track["vector"]
        track["vector"]=value.flatten
      end
    end
  end
end


signal.each do | block |
  if block.kind_of?(Array)
    block.each  do| track|
      if track.kind_of?(String)
        type=track
      else
        track["event"]=Hash.new
        tic=0
        lastValue=track["vector"][0]
        track["event"][tic]=track["vector"][0]
        track["vector"].each do | value |
          if value != lastValue
            track["event"][tic]=value
            lastValue=value
          end
          tic += 1
        end
      end
    end
  end
end
pp pattern
