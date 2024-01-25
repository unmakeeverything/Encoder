#!/bin/bash

sudo apt-get install sshfs ffmpeg bc -y
sudo modprobe fuse

sudo adduser $USER fuse
sudo chown root:fuse /dev/fuse
sudo chmod +x /dev/fusermount

mkdir ~/remoteDir
sshfs $USER@192.168.10.23:/mnt/d ~/remoteDir

mkdir ~/remoteDir2
sshfs $USER@192.168.10.23:/mnt/e ~/remoteDir2

mkdir ~/remoteDir3
sshfs $USER@192.168.10.23:/mnt/f ~/remoteDir3
