In 2020, I was tasked with creating digital signage for a Jeep dealership. The client wanted to mount eight TVs — four on either side of their vehicle showroom — and have them play a collection of ~400 lifestyle videos asynchronously. Right away, the thought of using Raspberry Pis came to mind. The Pi 4b, with its dual-monitor capability, seemed like the obvious choice for this project. I bought four of them, intending to drive two TVs with each.

Solid plan, as you'll no doubt agree. In fact, the plan was so solid, I was positive someone else had done it already. But no! To my surprise, no one had. Some solutions existed, but none supported two displays. So, I took on the challenge myself. In the end, I was able to turn the Pi 4b into a totally hassle-free, plug-and-play video looping device. Read on to learn how you can do the same.

**What You'll Need**
- Raspberry Pi 4b
- Adequate cooling (heatsinks + 40mm fan recommended)
- Raspberry Pi OS Lite, 2020-02-13 or newer
- USB flash drive

**Notes**
- My project required video alone. Audio was not a consideration. Sound does work, but keep in mind that only one of the micro-HDMI ports on the Pi 4b carries audio.
- Omxplayer is lightweight and fast, but not as robust as VLC and other media players. Because omxplayer can only play a handful of formats, I purposely designed my script to ignore files with extensions other than .mp4. For best results, use 1080p videos with h.264 encoding in mp4 format.
- The Pi 4b is hardware-limited to 1080p @ 60hz per display or 2160p (4k) @ 30hz per display. Omxplayer will skip videos that exceed these specifications.

## Setting Up USB Auto-Mounting

A USB stick is the most logical place to store your video files. That way, you or your client can easily add and replace videos in the future. Raspberry Pi OS doesn't automatically mount USB storage media by default, so our first step is to enable this behavior.

There are several ways to accomplish this, especially if you know the device's UUID. But since we can't be sure whether the same USB stick will always be used with your Pi, we'll employ a more comprehensive method.

The instructions provided by [pauliucxz on StackExchange](https://raspberrypi.stackexchange.com/questions/66169/auto-mount-usb-stick-on-plug-in-without-uuid) are perfect for our needs. With a udev rule, systemd service, and mount script, we can ensure that any attached USB stick is not just mounted at boot, but also assigned a predictable mount point.

#### Dependencies

Install the required pmount package using `sudo apt-get install pmount`.

#### Udev Rule

Create the file `/etc/udev/rules.d/usbstick.rules` with the following content:

```
ACTION=="add", KERNEL=="sd[a-z][0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}="usbstick-handler@%k"
```

#### Systemd Service

Create the file `/lib/systemd/system/usbstick-handler@.service` with the following content:

```
[Unit]
Description=Mount USB sticks
BindsTo=dev-%i.device
After=dev-%i.device

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/cpmount /dev/%I
ExecStop=/usr/bin/pumount /dev/%I
```

#### Mount Script

Create the file `/usr/local/bin/cpmount` with the following content:

```
#!/bin/bash
if mountpoint -q /media/usb1 ; then
  if mountpoint -q /media/usb2 ; then
    if mountpoint -q /media/usb3 ; then
      if mountpoint -q /media/usb4 ; then
        echo "No mountpoints available!"
      else
        /usr/bin/pmount --umask 000 --noatime -w --sync $1 usb4
      fi
    else
      /usr/bin/pmount --umask 000 --noatime -w --sync $1 usb3
    fi
  else
    /usr/bin/pmount --umask 000 --noatime -w --sync $1 usb2
  fi
else
  /usr/bin/pmount --umask 000 --noatime -w --sync $1 usb1
fi
```

Make the file executable for the root user using `sudo chmod u+x /usr/local/bin/cpmount`, then insert your USB stick and reboot. If you did everything correctly, your USB stick should now be mounted at `/media/usb1` automatically at system startup.

## Installing Playback Script

Now that we have a consistent location for our videos, we can install the script responsible for playing them. I call the following script “Video4Pi.” Based loosely on a script written by [AliOs from Key to Smart](https://keytosmart.com/single-board-computers/looping-video-playlist-omxplayer-raspberry-pi/), my script adds useful features and the ability to drive two separate displays.

#### Dependencies

Install the required *omxplayer* package using `sudo apt-get install omxplayer`.

#### Parent Script

Create the file `~/video4pi.sh` with the following content:

```
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
```

Make the file executable using `chmod +x ~/video4pi.sh`.

#### Child Scripts

Next, we're going to create two child scripts — one for each display. Their purpose is to track each display's independent playback status and signal the parent script to load a new video once the current video is finished.

Create the file `~/screen1.sh` with the following content:

```
#!/bin/bash
omxplayer $screen1_options "$entry" > /dev/null
```

Create the file `~/screen2.sh` with the following content:

```
#!/bin/bash
omxplayer $screen2_options "$entry" > /dev/null
```

Make both files executable using `chmod +x ~/screen1.sh ~/screen2.sh`.

#### Config File

The Video4Pi script is highly configurable. All settings can be managed via a config file, which we'll now place on the USB stick containing your videos. This will make it easy for you to change settings at any time without dislocating the Pi.

Create the file `/media/usb1/config.txt` with the following content:

```
# This file should be stored on your USB device. Edit the variables below to
# customize the Video4Pi script's behavior for your needs.
# ------------------------------------------------------------------------------

# Setting to false prevents playback from starting. Useful for debugging.
    run="true"

# When set to true, displays are synchronized. When set to false, displays
# act independently. Note: if shuffle is false, displays will be identical
# regardless of the sync setting.
    sync="false"

# When true, videos are played at random. When false, videos are selected by
# filename in alphanumeric order.
    shuffle="true"

# Sets a delay period between videos (in seconds).
    between="0"

# ------------------------------------------------------------------------------
# CAUTION: Settings below this line should not be changed unless you know
# exactly what you're doing! Faulty values may cause the script to malfunction.
    screen1_options="--display=2" # omxplayer arguments for 1st display
    screen2_options="--display=7 --no-keys" # omxplayer arguments for 2nd display
```

Edit the variables in this file to suit your needs. As it explains, you can use the “sync” and “shuffle” variables to decide whether your two displays are synchronized or independent. If you want more advanced control over playback on either display, you can append additional [omxplayer arguments](https://www.raspberrypi.org/documentation/raspbian/applications/omxplayer.md) to the “screen1_options” and “screen2_options” variables.

## Increasing GPU Memory

After that last step, you probably tried to test the parent script... only to be told by omxplayer to “have a nice day!” That's because there isn't enough memory allocated to the GPU to play two videos at once. Let's fix that.

Bring up the raspi-config utility using `sudo raspi-config`.

![Alt text](/assets/img/blog/Video4PiHowTo01.jpg "Title")

Beginning from the main menu, select “Advanced Options” followed by “Memory Split.” When prompted, enter 512 as the new value and select “Ok” to confirm the change. This will allocate 512 MB of system memory to the GPU.

This is the maximum amount the OS will allow, so don't bother entering a higher number. It will just reset to default. On the other hand, you're welcome to try allocating less memory, but I don't advise it. Some videos are more demanding of the GPU than others. Giving it all the memory you can spare guarantees a seamless experience.

![Alt text](/assets/img/blog/Video4PiHowTo02.jpg "Title")

When you're finished with that, reboot. Now, try running the parent script again. With more available memory, the script should work as expected and you should get output on both displays. We're almost done! Use Ctrl+C to exit the script before moving on to the final steps.

## Starting Playback Script at Boot

Most likely, you want videos to start playing automatically when the Pi is turned on. To make that happen, all you need to do is make `~/video4pi.sh` run at boot. Any way you choose to accomplish this is fine.

A quick and dirty method is to add the script to the default user's bash profile. This can be done with a single command: `echo "source ./video4pi.sh" > ~/.bash_profile`.

With that in place, Video4Pi should now start by itself each time the system boots. Feel free to test this now if you like. But use Ctrl+C during the script's countdown to cancel it for the time being, as there's one more thing we should do before wrapping this up.

## Enabling OverlayFS

You can't rely on your client to log in and initiate a clean shutdown when they want to turn off the Pi. Plus, there's always the danger of a power outage. Regardless of how they happen, unclean shutdowns cause filesystem corruption that can cripple a Raspberry Pi in a matter of weeks.

Luckily, we can avoid that outcome by making the Pi's filesystem effectively read-only. Now an included option in Raspberry Pi OS, OverlayFS makes it so that all writes to the root filesystem are stored in memory instead of on the SD card. When we're through, you'll be able to safely unplug your Pi just like you would a desk lamp or kitchen appliance. It won't need to be shut down properly like a PC.

Launch *raspi-config* again using `sudo raspi-config`. Just like before, select “Advanced Options” from the main menu. From the advanced menu, select “Overlay FS” and answer yes to all of the prompts. When asked if you'd like to reboot, do so.

![Alt text](/assets/img/blog/Video4PiHowTo03.jpg "Title")

With OverlayFS enabled, you can count on your Raspberry Pi to work reliably no matter what. Best of all, it's completely reversible. If you want to write changes to the disk later on, simply use *raspi-config* to disable OverlayFS, returning the root filesystem to normal.

That's it! Your Raspberry Pi 4b is now ready for use as a dedicated dual-output video looping device.