#!/bin/bash

# Detect number of connected displays
read -r dispcount _ < <(tvservice --list)

# Mount point of USB device
videos="/media/usb1"

# Default variables (overriden by config.txt file on USB device if present)
run="true"
sync="true"
shuffle="true"
between="0"
screen1_options="--display=2"
screen2_options="--display=7 --no-keys"

# Check for video files on USB device
if ls $videos/*.mp4 &>/dev/null ; then
  filecount=$(ls $videos/*.mp4 | wc -l)
else
  filecount=0
fi

# Get custom configuration file from USB device
if [[ -f $videos/config.txt ]]; then
  custom="true"
  source $videos/config.txt
fi

# Provision for invalid 'between' values
case $between in
  ''|*[!0-9]*) between=0 ;;
  *) ;;
esac

# Disable cursor for clean video transitions
setterm -cursor off;

# Intro message
echo -e "--------------------------------------------------------------------------------\n"
echo -e "\nThis program is intended to play videos with h.264 encoding in .mp4 format only!
GPU hardware decoding on this device is limited to 1920x1080 @ 60hz. Videos with
greater resolution or frame rate will be skipped."
echo -e "\nPress Ctrl+C to stop the program now."
echo -e "\n--------------------------------------------------------------------------------"
if $custom = "true" ; then
  echo -e "\nConfiguration override file found. Proceeding with the following settings:"
fi
echo -e "\nSync is $sync | Shuffle is $shuffle | Delay between videos is $between seconds"
echo -e -n "\nFound $filecount compatible videos. "

# Begin perpetual loop
if $run = "true" ; then
  if [ "$filecount" -gt "0" ] ; then
    echo -n "Starting in "
    for i in {5..1}; do echo -n "$i... " && sleep 1; done
    while true; do
      if $shuffle = "true" ; then
        playlist1=$(for entry in $videos/*.mp4 ; do echo "$entry" ; done | sort -R)
        playlist2=$(for entry in $videos/*.mp4 ; do echo "$entry" ; done | sort -R)
      else
        playlist1=$(for entry in $videos/*.mp4 ; do echo "$entry" ; done)
        playlist2=$(for entry in $videos/*.mp4 ; do echo "$entry" ; done)
      fi
      if [ "$dispcount" -gt "1" ] ; then
        if $sync = "true" ; then
          if ps ax | grep -v grep | grep omxplayer > /dev/null ; then
            sleep 1;
          else
            for entry in $playlist1 ; do
              clear
              omxplayer $screen1_options "$entry" > /dev/null &
              omxplayer $screen2_options "$entry" > /dev/null
              sleep $between
            done
          fi
        else
          if ps ax | grep -v grep | grep "screen1.sh" > /dev/null ; then
            sleep 1;
          else
            for entry in $playlist1 ; do
              clear
              source ./screen1.sh
              sleep $between
            done
          fi &
          if ps ax | grep -v grep | grep "screen2.sh" > /dev/null ; then
            sleep 1;
          else
            for entry in $playlist2 ; do
              clear
              source ./screen2.sh
              sleep $between
            done
          fi
        fi
      else
        if ps ax | grep -v grep | grep omxplayer > /dev/null ; then
          sleep 1;
        else
          for entry in $playlist1 ; do
            clear
            omxplayer $screen1_options "$entry" > /dev/null
            sleep $between
          done
        fi
      fi
    done
  fi
else
  echo "Run is set to false; exiting."
fi