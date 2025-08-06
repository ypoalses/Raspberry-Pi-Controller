# Build pipeline for Raspberry Pi Zero (32-bit) image with PM2

Two ways to produce the image:

## A) GitHub Actions (recommended)
1. Create a new GitHub repo and commit the contents of this zip, including `sa-image/`.
2. Push to `main`.
3. In GitHub: **Actions → Build Raspberry Pi Zero Image (PM2)** → **Run workflow**.
4. When it completes, download the `.img` from the **Artifacts**.

## B) Local build
```bash
chmod +x build_local.sh
./build_local.sh
```
The script clones `rpi-image-gen`, picks the 32‑bit Lite config, builds, and prints the path(s) to the generated `.img`.

## After flashing
1. Use Raspberry Pi Imager → “Use custom” → select the built `.img`.
2. Edit the SD card’s **boot** partition: copy `provision.env.example` to `provision.env` and fill in:
   - `TAILSCALE_AUTH_KEY` (optional, recommended to be short‑lived)
   - App environment variables (`NODE_ENV`, `ENCRYPTION_KEY`, etc.)
3. Boot the Pi Zero; PM2 should start the app under the `controller` user.

> To customize packages or first‑boot steps, edit files under `sa-image/` then rebuild.
