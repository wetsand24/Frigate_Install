# Frigate 0.18 + Reolink + Intel GPU

The files from the video. Frigate records your camera on your own computer and uses the Intel graphics chip for the AI. You don't need a Coral or a cloud plan.

## Files

| File | Where it goes on the server | What to change |
|---|---|---|
| `compose.yaml` | `/opt/frigate/compose.yaml` | nothing |
| `.env.example` | `/opt/frigate/.env` | your camera's guest username and password |
| `config/config.yml` | `/opt/frigate/config/config.yml` | your camera's IP address (one line) |
| `add-camera-user.sh` | anywhere on the server | nothing: it asks you for the camera's address and passwords |

## Steps (as in the video)

On the Linux computer's own screen (skip the `apt install` line if SSH is already installed):

```bash
hostname -I                      # the first number is the server's address
apt install -y openssh-server
systemctl enable --now ssh
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/password.conf   # some images switch password login off
systemctl restart ssh
```

From your Windows PC, in Terminal (use your own username on the server):

```bash
ssh YOURUSER@SERVER-IP
su -                             # become root (Ubuntu: sudo -i)
apt update && apt upgrade -y
apt install -y curl
curl -fsSL https://get.docker.com | sh
ls /dev/dri                      # you should see renderD128
nano add-camera-user.sh          # paste the script, Ctrl+O, Enter, Ctrl+X
bash add-camera-user.sh          # makes a watch-only user "frigate" on the camera (the Reolink doorbell's app and web page can't)
mkdir -p /opt/frigate/config /srv/frigate
cd /opt/frigate
nano compose.yaml                # paste, Ctrl+O, Enter, Ctrl+X
nano .env
nano config/config.yml
docker compose up -d
docker logs frigate 2>&1 | grep -o 'Password: .*'
```

Then open `https://YOUR-SERVER-IP:8971`. The username is `admin`, and the password is the one from the log.

## More cameras

Each camera has two parts in `config/config.yml`, linked by the same name:

- **Under `go2rtc: streams:`**, its line with the camera's real address. go2rtc (built into Frigate) connects to the camera once and keeps a copy of the video on the server.
- **Under `cameras:`**, its block. Its `path:` points at `127.0.0.1` (this same server) and takes go2rtc's copy by name: `rtsp://127.0.0.1:8554/doorbell`.

For a second camera, in nano (as in the video):

1. On the `doorbell:` line under `go2rtc: streams:`, press **Alt+A**, the down arrow twice, **Alt+6** (copy), then **Ctrl+U** (paste). Rename the copy `garage:` and put the second camera's IP address in its line.
2. On the `doorbell:` line under `cameras:`, press **Alt+A**, arrow down to the end of the block, **Alt+6**, then paste it with **Ctrl+U**. Rename the copy `garage:` and change the end of its `path:` from `doorbell` to `garage`. For a 16:9 camera set `width: 1280` and `height: 720`.
3. The `.env` login is reused, so make the same `frigate` user on that camera too (`bash add-camera-user.sh`).
4. Save (Ctrl+O, Enter, Ctrl+X), then `docker compose restart`.

## 4K and other Reolink cameras

The `flv` line in `config/config.yml` works on any Reolink camera up to 5 MP, like the doorbell in the video. For bigger cameras, it depends on the model ([Frigate's Reolink notes](https://docs.frigate.video/configuration/camera_specific/)):

| Camera | What to use |
|---|---|
| 5 MP or lower | the `flv` line as it is |
| 6 MP or higher (4K is 8 MP), newer models like the Duo 3 or CX-8xx | the `flv` line as it is |
| 6 MP or higher, older models like the RLC-8xx | RTSP instead (below) |

For RTSP, replace that camera's line under `go2rtc: streams:` with this one (Reolink's main-stream address; `554` is Reolink's default RTSP port):

```yaml
      - "rtsp://{FRIGATE_CAMERA_USER}:{FRIGATE_CAMERA_PASSWORD}@CAMERA_IP:554/Preview_01_main"
```

Tips:
- Most Reolink cameras are 16:9, so set `width: 1280` and `height: 720` under `detect:`.
- Reolink says not to use special characters in the camera password.
- Reolink models don't all behave the same. If the picture stays black, check the Frigate notes linked above for your model.

## Optional: save recordings on a NAS

Frigate saves everything in `/srv/frigate`. To keep the recordings on a NAS instead, mount a NAS share at that folder **before** you start Frigate. If Frigate is already running, stop it first with `docker compose down`.

**1. On the NAS:** create a shared folder (for example `frigate`) and turn on NFS for it. Allow your Frigate server's IP address with read/write access.

**2. On the Frigate server:**

```bash
apt install -y nfs-common
echo 'NAS-IP:/path/to/frigate  /srv/frigate  nfs  defaults,_netdev  0  0' >> /etc/fstab
systemctl daemon-reload
mount -a
df -h /srv/frigate               # should show the NAS, not the local disk
```

Replace `NAS-IP:/path/to/frigate` with your NAS's address and the share's export path. Synology export paths look like `/volume1/frigate`.

**3.** Run `docker compose up -d`. You don't need to change `compose.yaml`, because it already uses `/srv/frigate`.

Tips:
- Use a wired connection for the NAS. Recording runs all day.
- If the NAS is off when the server boots, the folder isn't mounted and recordings go to the local disk. Run `df -h /srv/frigate` to check where they're going.
