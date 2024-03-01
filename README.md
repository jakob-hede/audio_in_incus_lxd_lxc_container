# Audio in Incus (LXD/LXC) container

#### This guide will show you _some_ of how to set up audio in an Incus container.

### "Modern" Linux audio is a bit of a mess, between pipewire and pulseaudio.

I will set up both pipewire and pulseaudio in the container.  
First pulseaudio, then pipewire.

This was done with both host and container running Fedora 39.
At least the host is running pipewire-pulseaudio, and probably also the container.

- In container `containor`:
  - Username: `kilo`
  - UID: `1000`
- On host:
  - UID: `1000`

## Pulseaudio:
The pulseaudio socket is at `/run/user/1000/pulse/native` on the host.  
The container is given access to it in a profile like so:



```yaml
# Profile audio_01_pulsewire_socket:
config:
  environment.PULSE_SERVER: unix:/home/kilo/.pulsewire-native-socket
description: Audio socket for PulseAudio
devices:
  PulseSocket1:
    bind: container
    connect: unix:/run/user/1000/pulse/native
    gid: "1000"
    listen: unix:/home/kilo/.pulsewire-native-socket
    mode: "0777"
    security.gid: "1000"
    security.uid: "1000"
    type: proxy
    uid: "1000"
name: audio_01_pulsewire_socket
```
Environment variable `PULSE_SERVER` must be set to the socket in the container,
for apps in the container to use pulseaudio.

The `environment.PULSE_SERVER` in the profile might be useful for something 
but in order to get it working for apps in the container,
I needed to export it _regularly_ inside the container:

`[kilo@containor ~]$ nano .bashrc`
```shell
# audio for pulseaudio
export PULSE_SERVER=unix:/home/kilo/.pulsewire-native-socket
```
With this I could `paplay test.wav` inside container and hear the sound on the host

#### So this is probably all that is needed for ordinary audio in a container, but I also wanted to try pipewire.

## Pipewire:
The pipewire socket is at `/run/user/1000/pipewire-0` (or `...pipewire-0-manager`) on the host.  
The container is given access to it (them?) in a profile like so:
```yaml
# Profile audio_02_pipewire_socket:
config:
  environment.PIPEWIRE_REMOTE: /tmp/pipewire-0-manager
description: Audio socket for Pipewire
devices:
  PipewireSocket1:
    bind: container
    connect: unix:/run/user/1000/pipewire-0
    gid: "1000"
    listen: unix:/tmp/pipewire-0
    mode: "0777"
    security.gid: "1000"
    security.uid: "1000"
    type: proxy
    uid: "1000"
  PipewireSocket2:
    bind: container
    connect: unix:/run/user/1000/pipewire-0-manager
    gid: "1000"
    listen: unix:/tmp/pipewire-0-manager
    mode: "0777"
    security.gid: "1000"
    security.uid: "1000"
    type: proxy
    uid: "1000"
name: audio_02_pipewire_socket
```
I found that I needed to bind BOTH the pipewire-0 and pipewire-0-manager sockets
to the container, in order to get any of them to appear,
and then only pipewire-0-manager appears in /tmp/ in container. _Weird_.  
(_It is arbitrary that I've chosen /tmp/ as the location in the container for this,
instead of /home/kilo/._)

Again to export; add `PIPEWIRE_REMOTE`:

`[kilo@containor ~]$ nano .bashrc`
```shell
# audio for both pulseaudio and pipewire:
export PULSE_SERVER=unix:/home/kilo/.pulsewire-native-socket
export PIPEWIRE_REMOTE=/tmp/pipewire-0-manager
```
With this I could `pw-play test.wav` inside container and hear the sound on the host

## GUI apps:
This works for me with _GUI apps_."
I use X11 with this profile:
```yaml
# Profile x11:
config:
  environment.DISPLAY: :0
  environment.PULSE_SERVER: unix:/home/sermin/pulse-native
description: GUI X11 profile
devices:
  X0:
    bind: container
    connect: unix:@/tmp/.X11-unix/X0
    listen: unix:@/tmp/.X11-unix/X0
    security.gid: "1000"
    security.uid: "1000"
    type: proxy
  mygpu:
    type: gpu
name: x11
```

## Remarks:
> - Relevant packages in container:
>  - dnf install pipewire  # Includes pipewire-pulseaudio - at least on Fedora 39
>  - dnf install pulseaudio-utils
>  - dnf install pipewire-utils

I left systemd handling of pipewire and pulseaudio as was.

Yes. The two exports differ as to the prefix `unix:`

I have not tried Wayland, but there is this guide:
[LXD Containers for Wayland GUI Apps](https://blog.swwomm.com/2022/08/lxd-containers-for-wayland-gui-apps.html)

> The pipewire socket does not work alone. It needs the pulseaudio socket as well.  
The only difference I have observed is that it allows the pipewire-utility `pw-play` to work.  
This I take to indicate that _a pipewire API-ish_ is working, and that this might enable other apps to use this API.  
That pipewire in container is dependent on pulseaudio might be due to how my host is set up.  
I do not understand the details of this.

I struggled quite to get this working. Now (some of) it seems so simple ...

Thanks to the Incus/LXD/LXC community for [helping out with this](https://discuss.linuxcontainers.org/t/audio-via-pulseaudio-inside-container/8768).
