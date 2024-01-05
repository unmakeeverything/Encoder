sudo apt-get install sshfs ffmpeg bc -y
sudo modprobe fuse

sudo adduser $USER fuse
sudo chown root:fuse /dev/fuse
sudo chmod +x /dev/fusermount

mkdir ~/remoteDir

sshfs $USER@192.168.10.23:/mnt/e ~/remoteDir

mkdir ~/remoteDir2

sshfs $USER@192.168.10.23:/mnt/d ~/remoteDir2