# SA Image Skeleton for Raspberry Pi Zero / Zero W (Bookworm, 32‑bit)

This folder is meant to be used as the **external customization directory** for `rpi-image-gen`.
It includes:
- a **meta** layer to install packages and enable a first-boot service,
- a **rootfs overlay** with a one-time `firstboot` service + script,
- a **profile** that pulls in your meta layer.

> Target hardware: Raspberry Pi Zero / Zero W / Zero WH  
> Target OS: Raspberry Pi OS Lite (Bookworm, 32‑bit / armhf)

---

## Prerequisites

1. Build host: Linux (Ubuntu/Debian or Raspberry Pi OS 64‑bit recommended).
2. Install `git` and clone rpi-image-gen:

```bash
git clone https://github.com/raspberrypi/rpi-image-gen.git
cd rpi-image-gen
sudo ./install_deps.sh   # if provided by the repo
```

3. Identify the **32‑bit Lite** config file inside `rpi-image-gen/config/` (its name usually contains `armhf` and `lite`).  
   Print candidates:
```bash
ls config/*armhf*lite* 2>/dev/null || ls config
```

---

## How to build

From the `rpi-image-gen` repo root:

```bash
# Replace CONFIG_PATH with the path to the 32‑bit Lite YAML in rpi-image-gen/config
./build.sh -c CONFIG_PATH ./sa-image
```

The generated `.img` will be placed in the repo's output directory (see rpi-image-gen README).  
Flash it with Raspberry Pi Imager (“Use custom”) or balenaEtcher.

---

## Customizing packages

Edit `meta/sa-packages.yaml` and put your APT packages under `packages.install`.
You can also add `pip` or other installers under `chroot.customize` steps.

**Example:**
```yaml
packages:
  install:
    - git
    - curl
    - net-tools
    - unzip
    - ca-certificates
```

> After changing packages/configs, re-run the build command to create a new image.

---

## First-boot behaviour

On first boot the service:
- sets a unique hostname based on the device serial (e.g., `pi-<last6>`),
- regenerates SSH host keys if missing,
- runs your optional bootstrap (git pull, fetch site config, register device),
- disables itself when done.

Edit the script at:
```
device/rootfs-overlay/usr/local/sbin/firstboot.sh
```
and the unit at:
```
device/rootfs-overlay/etc/systemd/system/firstboot.service
```

---

## Per-batch Wi‑Fi (optional)

Prefer setting Wi‑Fi SSID/PSK per batch using **Raspberry Pi Imager → Advanced** when flashing cards.  
If you need the image to auto-join Wi‑Fi, you can drop a preseeded `wpa_supplicant.conf` into the overlay:
```
device/rootfs-overlay/etc/wpa_supplicant/wpa_supplicant.conf
```
But avoid baking secrets into the image if you’ll ship it widely.

---

## Notes

- This image targets **armhf (32‑bit)** so it boots on **Zero**/*Zero W*.
- Use high‑endurance A1/A2 microSD cards and keep logging/swap modest for longevity.
- If you need a fully reproducible “from-scratch OS” pipeline, consider `pi-gen`. This skeleton focuses on `rpi-image-gen` for faster iteration.

## Provisioning
- Edit `/boot/provision.env` **after flashing** to inject Tailscale auth key and app `.env` values.
- The first-boot service consumes this file and then starts the Node app under systemd.

**Security**: Do not bake private SSH keys or long-lived secrets into the image. Use short-lived Tailscale auth keys or pre-authorized tagging.
