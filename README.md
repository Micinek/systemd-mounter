# systemd-mounter
### A shortcut bash script for easy management of systemd mount services. Handles creation, mounting and removal of unused mounts in one simple .yaml file.

#
Script takes input from file mounts.yaml in nice, clearly readable form of... you guessed it... YAML, and makes systemd service for each mount.

### Example for NFS mount
```yaml
mounts:
  - name: movies
    what: "synology-nas.network.local:/volume1/media"
    where: "/synology/media"
    type: "nfs"
    options: "rw,async,nfsvers=3,noatime,rsize=2097152,wsize=2097152,nolock,soft"
    before_docker: true
```
#

### Example for CIFS mount with secured credentials:
```yaml
mounts:
  - name: downloads
    what: "//synology-nas.network.local/downloads"
    where: "/synology/downloads"
    type: "cifs"
    options: "credentials=/path-to/synology-nas.creds,iocharset=utf8,rw,vers=3.0,nofail,soft"
    before_docker: true
```
#### synology-nas.creds:    ( used only for CIFS )
```txt
username=youruser
password=yourpassword
```
Also, you should secure your .creds file so no other user can read them:
```bash
sudo chmod 600 /path-to/synology-nas.creds
```
#


### Explanation of options:
name: just a name of service or mount

what: remote mount, for example synology NAS with NFS

where: local mountpoint

type: NFS or CIFS    ( can be whatever your system supports )

Explanation of Options: ( you can find all options in documentation or just google it)
- rw → Read & Write access
- async → Asynchronous writes (better performance, but might risk data loss on power failure - i have UPS, so it's mostly fine)
- nfsvers=3 → Use NFSv3 (my synology supports only NFSv3)
- noatime → Disables updating access times (reduces disk writes, improves performance)
- rsize=2097152,wsize=2097152 → The default NFS buffer size is often 1 MB (1048576 bytes), which works well for most scenarios, but on a 2.5 Gbit network, you can benefit from larger buffer sizes like 2 MB or even 4 MB.
- nolock → Disables file locking (useful for media files, avoids issues with Docker)
- soft → Fails quickly if the NAS is unreachable (prevents system hangs)

before_docker: I designed this with intention to mount all needed mountpoints BEFORE docker.service starts ( my media stack ), so i added this for systemd to do this before it goes to start docker.service

#### <span style="color:red"> DISCLAIMER: these options may not work for everyone, so read documentation or do your own testing of what options are best for your usecase. </span>
#

### I created this script to help me faster organize and create mounts on my systems, i create and delete lot of VMs that i test new stuff on. I was tired of recreating mountpoints, deleting them, setting new ones, etc. So i created this helper, it is simple but it works for me :) I hope it helps you a bit ;)

#

### For those who want addition to my docker setup with this script:

If you want your docker.service, on any other service WAIT for mounts to be ready before starting ( for example media servers etc.)

You just edit your desired service:
```bash
sudo systemctl edit docker
```
And add wanted services and mountpoints, so the service WAITS for these services to start or mountpoints to be ready.
```bash
[Unit]
RequiresMountsFor=/synology/media/filmy /synology/media/serialy /synology/downloads /synology/fotky
After=synology-media-filmy.mount synology-media-serialy.mount synology-downloads.mount synology-fotky.mount
```

### <span style="color:red"> BUT be carefull. If you set up "wait for some service" and the service does not start, or mountpoint is not avalible ( for example you deleted the folder on your NAS ), your docker ( in this case ) won't start at all... </span>

### Potential Solutions for Failover:
If you want to avoid Docker being blocked indefinitely, you can add a timeout to your docker.service:

```bash
[Unit]
TimeoutSec=60
```

This will allow the mount to be ready for 60 seconds before timing out. If the mount isn't available in that time frame, Docker will proceed.
