--[[ This script is used to convert the special format lyric file of Kugou Music (.krc) , QQ Music (.qrc) and LyRiCs (.lrc) into ASS format.
You could get these lyric files from the software above or foobar2000 with "ESLyric" plugin.
--]]

local tr = aegisub.gettext
script_name = tr"Import Lyric File"
script_description = tr"Import Lyric File For Aegisub"
script_author = "domo&SuJiKiNen"
script_version = "1.4"

k_tag="\\K"  --you can change this to \\k or \\kf
NOT_SET_ENDTIME = -1

local json = require"json"
local ffi  = require('ffi')
local lyric_decoder = ffi.load("LyricDecoder.dll")

ffi.cdef[[
char *krcdecode(char *src, int src_len);
char *qrcdecode(char *src, int src_len);
void free(void *memblock);
]]

isstring = function(s)
if type(s) == "string" then
end
end
table.tostring = function(t)
assert(type(t), "table")
local result, result_n = {}, 0
local function convert_recursive(t, space)
  for key, value in pairs(t) do
	result_n = result_n + 1
	result[result_n] = ("%s[%s] = %s"):format(space,
											  isstring(key) and ("%q"):format(key) or key,
											  isstring(value) and ("%q"):format(value) or value)
	if type(value) == "table" then
	  convert_recursive(value, space .. "\t")
	end
  end
end
convert_recursive(t, "")
return table.concat(result, "\n")
end
bit = require("bit")

local ffi = require'ffi'
local bit = require'bit'
local rshift = bit.rshift
local lshift = bit.lshift
local bor = bit.bor
local band = bit.band
local floor = math.floor

local mime64chars = ffi.new("uint8_t[64]",
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
local mime64lookup = ffi.new("uint8_t[256]")
ffi.fill(mime64lookup, 256, 0xFF)
for i=0,63 do
mime64lookup[mime64chars[i]]=i
end

local u8arr= ffi.typeof'uint8_t[?]'
local u8ptr=ffi.typeof'uint8_t*'

--- Base64 decode a string or a FFI char *.
-- @param str (String or char*) Bytearray to decode.
-- @param sz (Number) Length of string to decode, optional if str is a Lua string
-- @return (String) Decoded string.
function base64_decode(str, sz)
if (type(str)=="string") and (sz == nil) then sz=#str end
local m64, b1 -- value 0 to 63, partial byte
local bin_arr = ffi.new(u8arr, floor(bit.rshift(sz*3,2)))
local mptr    = ffi.cast(u8ptr,bin_arr) -- position in binary mime64 output array
local bptr    = ffi.cast(u8ptr,str)
local i       = 0
while true do
	repeat
		if i >= sz then goto done end
		m64 = mime64lookup[bptr[i]]
		i=i+1
	until m64 ~= 0xFF -- skip non-mime characters like newlines
	b1=lshift(m64, 2)
	repeat
		if i >= sz then goto done end
		m64 = mime64lookup[bptr[i]]
		i=i+1
	until m64 ~= 0xFF -- skip non-mime characters like newlines
	mptr[0] = bor(b1,rshift(m64, 4)); mptr=mptr+1
	b1 = lshift(m64,4)
	repeat
		if i >= sz then goto done end
		m64 = mime64lookup[bptr[i]]
		i=i+1
	until m64 ~= 0xFF -- skip non-mime characters like newlines
	mptr[0] = bor(b1,rshift(m64, 2)); mptr=mptr+1
	b1 = lshift(m64,6)
	repeat
		if i >= sz then goto done end
		m64 = mime64lookup[bptr[i]]
		i=i+1
	until m64 ~= 0xFF -- skip non-mime characters like newlines
	mptr[0] = bor(b1, m64); mptr=mptr+1
end
::done::
return ffi.string(bin_arr, (mptr-bin_arr))
end


local function unicode_to_utf8(convertStr)
  if type(convertStr)~="string" then
  return convertStr
  end
local resultStr=""
  local i=1
while true do
  local num1=string.byte(convertStr,i)
	  local unicode
  if num1~=nil and string.sub(convertStr,i,i+1)=="\\u" then
		  unicode=tonumber("0x"..string.sub(convertStr,i+2,i+5))
		  i=i+6
  elseif num1~=nil then
		  unicode=num1
		  i=i+1
	  else
		  break
	  end
	  if unicode <= 0x007f then
		  resultStr=resultStr..string.char(bit.band(unicode,0x7f))
	  elseif unicode >= 0x0080 and unicode <= 0x07ff then
		  resultStr=resultStr..string.char(bit.bor(0xc0,bit.band(bit.rshift(unicode,6),0x1f)))
		  resultStr=resultStr..string.char(bit.bor(0x80,bit.band(unicode,0x3f)))
	  elseif unicode >= 0x0800 and unicode <= 0xffff then
		  resultStr=resultStr..string.char(bit.bor(0xe0,bit.band(bit.rshift(unicode,12),0x0f)))
		  resultStr=resultStr..string.char(bit.bor(0x80,bit.band(bit.rshift(unicode,6),0x3f)))
		  resultStr=resultStr..string.char(bit.bor(0x80,bit.band(unicode,0x3f)))
	  end
  end
resultStr=resultStr..'\0'
return resultStr
end

local function round(x, dec)
-- Check argument
if type(x) ~= "number" or dec ~= nil and type(dec) ~= "number" then
  error("number and optional number expected", 2)
end
-- Return number
if dec and dec >= 1 then
  dec = 10^math.floor(dec)
  return math.floor(x * dec + 0.5) / dec
else
  return math.floor(x + 0.5)
end
end

function filename_extension(filename)
if type(filename) ~= "string" then
  error("filename must be string")
end
return string.lower(string.match(filename,"%.([^%.\\/]+)$") or "")
end

function ass_line_template()
line = {}
line.class = "dialogue"
line.raw = "Dialogue: 0,0:00:00.00,0:00:05.00,Default,,0,0,0,,"
line.section = "[Events]"
line.comment = false
line.layer = 0
line.start_time = 0
line.end_time = 5000
line.style = "Default"
line.margin_l,line.margin_r,line.margin_t,line.margin_b = 0,0,0,0
line.actor,line.effect,line.text  = " "," ",""
line.extra = {}
return line
end

function ass_simple_line(st,et,text,cmd_str)
line = ass_line_template()
line.start_time = st
line.end_time   = et
line.text       = text
if type(cmd_str) == "string" then
  load(cmd_str)()
end
return line
end

function krc_handler(encoded_str)
local convert_subtitles = {}
local encoded_c_str = ffi.new("char[?]", (#encoded_str)+1)
ffi.copy(encoded_c_str, encoded_str)
decoded_p = lyric_decoder.krcdecode(encoded_c_str,#encoded_str)
decoded_str = ""
if decoded_p then
  decoded_str = ffi.string(decoded_p)
  ffi.C.free(decoded_p)
end

syln = 0
for krc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
  ass_line = krc_parse_line(krc_line)
  table.insert(convert_subtitles,ass_line)
end    

--  This part is for romaji in Krc file
--  Ignore translation by default
language = string.match(decoded_str,"%[language:([^%]]+)")
lan_text = unicode_to_utf8(base64_decode(language))
if lan_text and #lan_text>27 then --length of {"content":[],"version":1}
  romaji_or_tran = true
end
--aegisub.debug.out("Syllable Number："..tostring(syln).."\n")
if romaji_or_tran then
  str = json.decode(lan_text)
for i=1,#str.content do --Language Number
  romaji = {}
  for j=1,#str.content[i].lyricContent do --Sentence Number
	 for k=1,#str.content[i].lyricContent[j] do  --Syllable Number
	  table.insert(romaji,tostring(str.content[i].lyricContent[j][k]))
	 end
  end
  --aegisub.debug.out("Romaji Number: "..tostring(#romaji).."\n")
  if #romaji == syln then
    romaji_all    = romaji
    dia_config    = {}
    dia_config[1] = {class="label",x=0,y=0,label="Romaji lyrics found. Add them ?",width=5}
    btn_roma, config = aegisub.dialog.display(dia_config,{"Yes", "No"})
  elseif #romaji == #str.content[i].lyricContent then  --This is translation 
    romaji        = {}
  	--trans         = romaji
    --dia_config    = {}
    --dia_config[1] = {class="label",x=0,y=0,label="Translation found. Add it ?",width=5}
    --btn_trans, config = aegisub.dialog.display(dia_config,{"Yes", "No"})
  else
  end
end

if btn_roma == "Yes" then
  i = 1
  for krc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
   ass_line = romaji_parse_line(krc_line,romaji_all)
   table.insert(convert_subtitles,ass_line)
  end
end

-- if btn_trans == "Yes" then
  -- i = 1
  -- for krc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
   -- ass_line = trans_parse_line(krc_line,trans)
   -- table.insert(convert_subtitles,ass_line)
  -- end
-- end
end
  return convert_subtitles
end


function romaji_parse_line(krc_line, romaji)
lst,ldur,syls_str = string.match(krc_line,"^%[(%d+),(%d+)%](.*)$")
let   = lst + ldur
ltext = ""

for t3,t4,syl_text in string.gmatch(syls_str,"<(%d+),(%d+),%d+>([^<]+)") do
  kdur     = round(t4/10)
  syl_text = string.gsub(romaji[i],"　",string.format("{%s%d}　",k_tag,"0"))
  syl_text = string.gsub(syl_text,"{"..k_tag.."0}[　 ]*[\n\r]*","")
  ltext    = ltext..string.format("{%s%d}",k_tag,kdur)..syl_text
  i        = i + 1
end
ltext = string.gsub(ltext,"[\n\r]*","")
return ass_simple_line(lst,let,ltext,"line.actor='Romaji'")
end

function trans_parse_line(krc_line, trans)
lst,ldur,syls_str = string.match(krc_line,"^%[(%d+),(%d+)%](.*)$")
let   = lst + ldur
ltext = trans[i]
i     = i + 1
return ass_simple_line(lst,let,ltext,"line.actor='Trans'")
end

function krc_parse_line(krc_line)
lst,ldur,syls_str = string.match(krc_line,"^%[(%d+),(%d+)%](.*)$")
let   = lst + ldur
ltext = ""

for t3,t4,syl_text in string.gmatch(syls_str,"<(%d+),(%d+),%d+>([^<]+)") do
  kdur     = round(t4/10)
  syl_text = string.gsub(syl_text,"　",string.format("{%s%d}　",k_tag,"0"))
  syl_text = string.gsub(syl_text,"{"..k_tag.."0}[　 ]*[\n\r]*","")
  ltext    = ltext..string.format("{%s%d}",k_tag,kdur)..syl_text
  syln     = syln + 1
end
ltext = string.gsub(ltext,"[\n\r]*","")
return ass_simple_line(lst,let,ltext)
end

function qrc_handler(encoded_str)
local convert_subtitles = {}
local encoded_c_str = ffi.new("char[?]", (#encoded_str)+1)
ffi.copy(encoded_c_str, encoded_str)
decoded_p   = lyric_decoder.qrcdecode(encoded_c_str,#encoded_str)
decoded_str = ""
if decoded_p then
  decoded_str = ffi.string(decoded_p)
  ffi.C.free(decoded_p)
end
-- aegisub.debug.out(decoded_str)
decoded_str = string.gsub(decoded_str,"%((%d+,%d+)%)%((%d+,%d+)%)","%(%1%)⠀%(%2%)")
for qrc_line in string.gmatch(decoded_str,"%[%d+,%d+%][^%[]*") do
  ass_line = qrc_parse_line(qrc_line)
  table.insert( convert_subtitles,ass_line )
end
return convert_subtitles
end

function qrc_parse_line(qrc_line)
lst,ldur,syls_str = string.match(qrc_line,"%[(%d+),(%d+)%](.*)")
let   = lst + ldur
ltext = ""
for syl_text,t3,t4 in string.gmatch(syls_str,"(%(?[^%(]*)%((%d+),(%d+)%)") do
  kdur     = round(t4/10)
  syl_text = string.gsub(syl_text,"[^}]　",string.format("{%s%d}　",k_tag,"0"))
  syl_text = string.gsub(syl_text,"{"..k_tag.."0}[　 ]*[\n]+","")
  ltext    = ltext..string.format("{%s%d}",k_tag,kdur)..string.gsub(syl_text,"⠀","")
end
return ass_simple_line(lst,let,ltext)
end

LRC_DEFAULT_LINE_DURATION = 5000

-- LRC allows tenths, hundredths, or milliseconds. Convert every form to ms.
function lrc_time_2_ass_time(time_str)
local min,sec,fraction = string.match(time_str,"[%[<](%d+):(%d+)[%.:]?(%d*)[%]>]")
if not min then
  return nil
end
fraction = fraction or ""
local fraction_ms
if #fraction == 0 then
  fraction_ms = 0
elseif #fraction == 1 then
  fraction_ms = tonumber(fraction) * 100
elseif #fraction == 2 then
  fraction_ms = tonumber(fraction) * 10
else
  fraction_ms = tonumber(string.sub(fraction,1,3))
end
return tonumber(min)*60*1000 + tonumber(sec)*1000 + fraction_ms
end

function lrc_timed_segments(text, line_start, open_char, close_char)
local segments = {}
local cursor = 1
local segment_start = line_start
local found_timestamp = false
local explicit_end = nil
local pattern
if open_char == "[" then
  pattern = "%[(%d+:%d+[%.:]?%d*)%]"
else
  pattern = open_char.."(%d+:%d+[%.:]?%d*)"..close_char
end

while true do
  local tag_start,tag_end,time_value = string.find(text,pattern,cursor)
  if not tag_start then
	break
  end
  local segment_text = string.sub(text,cursor,tag_start-1)
  if segment_text ~= "" then
	table.insert(segments,{start_time=segment_start,text=segment_text})
  end
  segment_start = lrc_time_2_ass_time(open_char..time_value..close_char)
  found_timestamp = true
  cursor = tag_end + 1
end

if not found_timestamp then
  return nil,nil
end
local final_text = string.sub(text,cursor)
if final_text ~= "" then
  table.insert(segments,{start_time=segment_start,text=final_text})
else
  explicit_end = segment_start
end
return segments,explicit_end
end

function lrc_parse_line(lrc_line,offset,source_order)
local records = {}
local line_times = {}
local remaining = string.gsub(lrc_line,"^%s+","")

while true do
  local time_str,rest = string.match(remaining,"^(%[%d+:%d+[%.:]?%d*%])(.*)$")
  if not time_str then
	break
  end
  table.insert(line_times,lrc_time_2_ass_time(time_str) + offset)
  remaining = rest
  local next_tag = string.match(remaining,"^%s*(%[%d+:%d+[%.:]?%d*%])")
  if next_tag then
	remaining = string.gsub(remaining,"^%s+","")
  else
	break
  end
end

if #line_times == 0 then
  return records
end

local enhanced_segments,enhanced_end = lrc_timed_segments(remaining,line_times[1]-offset,"<",">")
if enhanced_segments then
  for i,line_start in ipairs(line_times) do
	local shift = line_start - line_times[1]
	local shifted_segments = {}
	for _,segment in ipairs(enhanced_segments) do
	  table.insert(shifted_segments,{start_time=segment.start_time + offset + shift,text=segment.text})
	end
	table.insert(records,{start_time=line_start,segments=shifted_segments,
	  explicit_end=enhanced_end and (enhanced_end + offset + shift) or nil,order=source_order + i/1000})
  end
  return records
end

-- Retain support for the older square-bracket word-timed LRC variant.
if #line_times == 1 and string.find(remaining,"%[%d+:%d+[%.:]?%d*%]") then
  local legacy_segments,legacy_end = lrc_timed_segments(remaining,line_times[1]-offset,"[","]")
  for _,segment in ipairs(legacy_segments or {}) do
	segment.start_time = segment.start_time + offset
  end
  table.insert(records,{start_time=line_times[1],segments=legacy_segments,
	explicit_end=legacy_end and (legacy_end + offset) or nil,order=source_order})
  return records
end

for i,line_start in ipairs(line_times) do
  table.insert(records,{start_time=line_start,text=remaining,order=source_order + i/1000})
end
return records
end

function lrc_record_end(records,index)
local record = records[index]
if record.explicit_end and record.explicit_end > record.start_time then
  return record.explicit_end
end
if records[index+1] and records[index+1].start_time > record.start_time then
  return records[index+1].start_time
end
if record.segments and #record.segments > 1 then
  local last = record.segments[#record.segments]
  local previous = record.segments[#record.segments-1]
  local previous_duration = last.start_time - previous.start_time
  if previous_duration > 0 then
	return last.start_time + previous_duration
  end
end
return record.start_time + LRC_DEFAULT_LINE_DURATION
end

function lrc_record_to_ass(record,end_time)
local ass_line = ass_simple_line(record.start_time,end_time,record.text or "")
if not record.segments then
  return ass_line
end

local first_start = record.segments[1] and record.segments[1].start_time or record.start_time
if first_start > record.start_time then
  ass_line.text = ass_line.text..string.format("{%s%d}",k_tag,round((first_start-record.start_time)/10))
end
for i,segment in ipairs(record.segments) do
  local segment_end = end_time
  if record.segments[i+1] then
	segment_end = record.segments[i+1].start_time
  end
  local duration = math.max(0,segment_end-segment.start_time)
  ass_line.text = ass_line.text..string.format("{%s%d}%s",k_tag,round(duration/10),segment.text)
end
return ass_line
end

function lrc_handler(lrc_strs)
local records = {}
local offset = tonumber(string.match(lrc_strs,"%[offset:%s*([%+%-]?%d+)%s*%]")) or 0
local normalized = string.gsub(lrc_strs,"^\239\187\191","")
normalized = string.gsub(normalized,"\r\n","\n")
normalized = string.gsub(normalized,"\r","\n")
local source_order = 0

for lrc_line in string.gmatch(normalized.."\n","(.-)\n") do
  source_order = source_order + 1
  local parsed = lrc_parse_line(lrc_line,offset,source_order)
  for _,record in ipairs(parsed) do
	if record.text ~= "" or (record.segments and #record.segments > 0) then
	  table.insert(records,record)
	end
  end
end

table.sort(records,function(a,b)
  if a.start_time == b.start_time then
	return a.order < b.order
  end
  return a.start_time < b.start_time
end)

local convert_subtitles = {}
for i,record in ipairs(records) do
  table.insert(convert_subtitles,lrc_record_to_ass(record,lrc_record_end(records,i)))
end
return convert_subtitles
end

function lyric_to_ass(subtitles)
local filename = aegisub.dialog.open('Select Lyric File',
									 '',
									 '',
									 'Supported Lyrics File (*.krc,*.qrc,*.lrc,*.elrc)|*.krc;*.qrc;*.lrc;*.elrc',
									 false,
									 true)
if not filename then
  aegisub.cancel()
end

local encoded_file = io.open(filename,"rb")
if not encoded_file then
  aegisub.debug.out("Failed to load encoded file")
  aegisub.cancel()
end
local encoded_str = encoded_file:read("*all")
encoded_file:close()

allow_ext   = { "krc","qrc","lrc","elrc" }
ext_handler = {
  krc = krc_handler,
  qrc = qrc_handler,
  lrc = lrc_handler,
  elrc = lrc_handler,
}
import_file_ext = filename_extension(filename)
handler = ext_handler[import_file_ext]
if not handler then
  aegisub.debug.out("Unsupported lyric file: "..filename)
  aegisub.cancel()
end
convert_subtitles = handler(encoded_str)
if convert_subtitles then
  subtitles.append(unpack(convert_subtitles))
end
end

aegisub.register_macro(script_name, script_description, lyric_to_ass)
