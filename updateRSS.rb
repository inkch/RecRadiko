require 'rexml/document'
require 'time'
require 'date'
require 'open-uri'

URL_TIMETABLE_XML = 'http://radiko.jp/v2/api/program/station/weekly?station_id='
DOC_ROOT_URL = "http://jagabouz.com"
DOC_ROOT_DIR = "/home/jagapi/nginx/jagabouz.com/www" # @raspi
#DOC_ROOT_DIR = "/Users/sputnikiMac/dev/raspi_dev_space/raspi_podcast" # @iMac
FILE_URL = DOC_ROOT_URL + "/podcast/episodes/" + ARGV[0] + ".m4a"
FILE_PATH = DOC_ROOT_DIR + "/podcast/episodes/" + ARGV[0] + ".m4a"
TODAY = Time.now.strftime("%a, %d %b %Y %H:%M:%S +0900")

def getFileSize(filePath)
  if File.exist?(filePath) then
    return File::stat(filePath).size
  else
    return 0
  end
end


def getDescription
  channel = ARGV[1]

  #2分前の時刻を取得
  dateNOW = DateTime.now - Rational(2, 24*60)  
  #現在の日時を任意のフォーマットで取得
  keyTimeNum = dateNOW.strftime("%Y%m%d%H%M%S").to_i 

  programXML = REXML::Document.new(open(URL_TIMETABLE_XML + channel))
  xmlRoot = programXML.root
  return titleGetter(xmlRoot, keyTimeNum)
end

def titleGetter(xmlRoot, keyTimeNum)
  station = xmlRoot.elements["stations/station/name"].text
  progsRoot = xmlRoot.elements["stations/station/scd"]
  progsRoot.elements.each("progs") do |progs|
    progs.elements.each("prog") do |prog|
      if prog.attributes["to"].to_i >= keyTimeNum then
        retString = station
        retString += "<br/>" + prog.elements["title"].text
        retString += "<br/>" + getOnAirTime(prog.attributes["ft"], prog.attributes["to"])
        return retString
      end
    end
  end
end

def getOnAirTime(startTimeStr, endTimeStr)
  startDate = Time.strptime(startTimeStr, "%Y%m%d%H%M%S")
  endDate = Time.strptime(endTimeStr, "%Y%m%d%H%M%S")
  return startDate.strftime("%Y.%m.%d %H:%M") + " - " + endDate.strftime("%H:%M")
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
REXML::CData.new(getDescription, nil, summary)
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
