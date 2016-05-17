require 'rexml/document'
require 'json'
require 'time'
require 'date'
require 'open-uri'

API_KEY = 'zBtVFDbSXjP8reZv5WGlXYPEBlr0j6Oi'
DOC_ROOT_URL = "http://jagabouz.com"
DOC_ROOT_DIR = "/home/jagapi/nginx/jagabouz.com/www" # @raspi
#DOC_ROOT_DIR = "/Users/sputnikiMac/dev/raspi_dev_space/raspi_podcast" # @iMac
FILE_URL = DOC_ROOT_URL + "/podcast/episodes/" + ARGV[0] + ".m4a"
FILE_PATH = DOC_ROOT_DIR + "/podcast/episodes/" + ARGV[0] + ".m4a"
TODAY = Time.now.strftime("%a, %d %b %Y %H:%M:%S +0900")

# チャンネル名を変換して返却
def getChannelCode(channel)
  if channel == 'fm'
    return 'r3'
  end
  return channel
end

# 実行された日付の番組表を取得するためのURLを返す
def getURL
  ch = getChannelCode(ARGV[1])
  day = Time.now.strftime("%Y-%m-%d")
  return "http://api.nhk.or.jp/v1/pg/list/130/#{ch}/#{day}.json?key=#{API_KEY}"
end

# Return JSON-Object
def getJSON
  apiURL = getURL
  apiResponse = open(apiURL).read
  return JSON.parse(apiResponse)
end

# Find matching program info.
# Return info as JSON-Object
def getMatchingProg
  keyTime = DateTime.now - Rational(2, 24*60)
  keyTimeNum = keyTime.strftime("%H%M").to_i
  jsonDoc = getJSON
  jsonRoot = jsonDoc['list']
  jsonPrograms = jsonRoot['r3']

  jsonPrograms.each do |program|
    progEndTime = getTimeFromAPITimeStamp(program['end_time'])
    progEndTimeNum = progEndTime.strftime("%H%M").to_i
    if progEndTimeNum >= keyTimeNum
      return program
    end
  end
end

# NHK-APIの時刻表記が独特なので、HH:mmのみを抽出して返す
# 単純に文字列として処理を行っている
# (*) 処理を軽くするためTimeオブジェクトへの変換は行わない
# [YYYY-MM-DD]T[HH:mm:SS]+09:00  => HH:mm
def getHHMM(rowTimeStr)
  return rowTimeStr[11,5]
end

# NHK-APIの独特な時刻表記から、Timeオブジェクトを取得
def getTimeFromAPITimeStamp(apiTimeStamp)
  return Time.strptime(apiTimeStamp, "%Y-%m-%dT%H:%M:%S+09:00")
end

# 番組が放送された日時をいい感じのフォーマットで返す
# YYYY.mm.dd HH:MM - HH:MM
def getPrettyOnAirTime(progInfo)
  today = Time.now.strftime("%Y.%m.%d")
  startTime = getHHMM(progInfo['start_time'])
  endTime = getHHMM(progInfo['end_time'])
  return "#{today} #{startTime} - #{endTime}"
end

# podcastのRSSに挿入するdescriptionを返す
# <br/>で改行した文字列として返す
def getPrettyDescription
  progInfo = getMatchingProg
  stationName = progInfo['service']['name']
  title = progInfo['title']
  onAirTime = getPrettyOnAirTime(progInfo)
  return "#{stationName}<br/>#{title}<br/>#{onAirTime}"
end

# 以下Debug用 ----------------------------------
p getPrettyDescription
#----------------------------------------------


def getFileSize(filePath)
  if File.exist?(filePath) then
    return File::stat(filePath).size
  else
    return 0
  end
end
#音声ファイルの存在チェック
fileSize = getFileSize(FILE_PATH)
if fileSize == 0 then
  p "\"" + FILE_PATH + "\" does NOT EXIST"
  return 1
end

xml = REXML::Document.new(File.new(DOC_ROOT_DIR + "/podcast/rss.xml"))
doc = xml.root

newItem = REXML::Element.new 'item'
newItem.add_element("title").add_text(ARGV[0])
newItem.add_element("link").add_text(DOC_ROOT_URL)
newItem.add_element("guid").add_text(FILE_URL)
newItem.add_element("description").add_text("")
summary = REXML::Element.new("itunes:summary")
REXML::CData.new(getPrettyDescription, nil, summary)
newItem.add_element(summary)
newItem.add_element("enclosure").add_attributes([["url",FILE_URL],["length",fileSize],["type","x-m4a"]])
newItem.add_element("category").add_text("Podcasts")
newItem.add_element("pubDate").add_text(TODAY)

doc.elements["channel"].insert_after("itunes:image",newItem)

newXML = ''
formatter = REXML::Formatters::Pretty.new
formatter.compact = true
formatter.write(doc.root, newXML)

puts newXML 

originalRSS = File.open(DOC_ROOT_DIR + "/podcast/rss.xml", "w+")
originalRSS.write newXML
originalRSS.close
