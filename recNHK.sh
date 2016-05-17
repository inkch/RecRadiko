#!/bin/bash

pid=$$
PLAYURL="http://www3.nhk.or.jp/netradio/files/swf/rtmpe.swf"
DATE=`date '+%Y-%m-%d-%H:%M'`
wkdir='/var/tmp'
date=`date +%Y%m%d_%H%M`
ymddate=`date +%Y.%m.%d`
default_dir="/home/jagapi/nginx/jagabouz.com/www/podcast/episodes"

# Usage
show_usage() {
  echo 'Usage:'
  echo ' RECORD MODE' 1>&2
  echo "   `basename $0` [-d out_dir] [-f file_name]" 1>&2
  echo '          [-t rec_minute] [-s Starting_position] channel' 1>&2
  echo '           -d  Default out_dir = $HOME' 1>&2
  echo '                  a/b/c = $HOME/a/b/c' 1>&2
  echo '                 /a/b/c = /a/b/c' 1>&2
  echo '                ./a/b/c = $PWD/a/b/c' 1>&2
  echo '           -f  Default file_name = channel_YYYYMMDD_HHMM_PID' 1>&2
  echo '           -t  Default rec_minute = 1' 1>&2
  echo '               60 = 1 hour, 0 = go on recording until stopped(control-C)' 1>&2
  echo '           -s  Default starting_position = 00:00:00' 1>&2
}

record() {
  rtmpdump --rtmp "${URL}" \
    --playpath "${PLAYPATH}" \
    --app "live" \
    -W "${PLAYURL}" \
    --live \
    --stop "${duration}" \
    --flv "${wkdir}/${tempname}.flv"

  avconv -ss ${starting}  -i "${wkdir}/${tempname}.flv" \
    -acodec copy "${wkdir}/${tempname}.m4a"
  mv -b "${wkdir}/${tempname}.m4a" "${outdir}/${filename}.m4a"
  rm -f "${wkdir}/${tempname}.flv"
  if [ $? -ne 0 ]; then
    echo "[stop] failed move file (${wkdir}/${tempname}.m4a to \
      ${outdir}/${filename}.m4a)" 1>&2 ; exit 1
  fi
  ruby /home/jagapi/nginx/jagabouz.com/www/podcast/.res/updateRSS_NHK.rb ${filename} ${channel}
}


# main ===============================================================================
while getopts df:t:s: OPTION
do
  case $OPTION in
    d ) OPTION_d=true
      VALUE_d="$OPTARG"
      ;;
    f ) OPTION_f=true
      VALUE_f="${ymddate}_${OPTARG}"
      ;;
    t ) OPTION_t=true
      VALUE_t="$OPTARG"
      if ! expr "${VALUE_t}" : '[0-9]*' > /dev/null ; then
        show_usage ; exit 1
      fi
      ;;
    s ) OPTION_s=ture
      VALUE_s="$OPTARG"
      ;;
    * ) show_usage ; exit 1 ;;
  esac
done

# Get Channel
shift $(($OPTIND - 1))
if [ $# -ne 1 ]; then
  show_usage ; exit 1
fi
channel=$1
URL="rtmpe://netradio-${channel}-flash.nhk.jp"

# Get Play-path
case $channel in
    r1) PLAYPATH='NetRadio_R1_flash@63346' ;;
    r2) PLAYPATH='NetRadio_R2_flash@63342' ;;
    fm) PLAYPATH='NetRadio_FM_flash@63343' ;;
    *) exit 1 ;;
esac

# Move directory & decide output directory
if [ ! "$OPTION_d" ]; then
  cd ${default_dir}
else
  if echo ${VALUE_d}|grep -q -v -e '^./\|^/'; then
    mkdir -p "${HOME}/${VALUE_d}"
    if [ $? -ne 0 ]; then
      echo "[stop] failed make directory (${HOME}/${VALUE_d})" 1>&2 ; exit 1
    fi
    cd "${HOME}/${VALUE_d}"
  else
    mkdir -p ${VALUE_d}
    if [ $? -ne 0 ]; then
      echo "[stop] failed make directory (${VALUE_d})" 1>&2 ; exit 1
    fi
    cd ${VALUE_d}
  fi
fi
outdir=${PWD}

# Get File Name
filename=${VALUE_f:=${channel}_${date}_${pid}}
tempname=${channel}_${pid}

# Get Duration 
min=${VALUE_t:=1}
duration=`expr ${min} \* 60`

# Get Starting Position
starting=${VALUE_s:='00:00:00'}

record
