# InfuseControlMod

A tiny Infuse tweak that stops the player controls (overlay) from popping up
every time a collection/playlist **auto-advances** to the next video. Manual
taps still bring the controls up, and the first video you open is left alone.

Tested target: Infuse 8 (classes confirmed by class-dumping the binary).
It loads via Substrate, which your InfusePlus IPA already includes, so it is
injected the same way InfusePlus is.

## Files
- `Tweak.x` — the hook (well commented; two tunables at the top).
- `Makefile`, `control`, `InfuseControlMod.plist` — Theos build + packaging.
- `inject-controlmod-only.yml` — **recommended.** Injects just this tweak into
  an IPA that **already has InfusePlus**. No InfusePlus re-download.
- `build-infuse-controlmod.yml` — alternative: builds this tweak and injects it
  **together with** InfusePlus into a plain decrypted Infuse IPA.

## Tunables (top of `Tweak.x`)
- `kTouchWindow` (default `1.5`): if you touched the screen within this many
  seconds before the item changed, the change is treated as user-initiated and
  the controls are left up. Lower it if a manual "Next" tap still hides them;
  raise it if autoplay still flashes the controls.
- `kLeaveFirstItemAlone` (default `YES`): keep the controls' normal behaviour on
  the first video of a session. Set `NO` to also open the first video with the
  controls hidden.

## Option A (recommended) — add ControlMod to your existing InfusePlus IPA
Your InfusePlus IPA already bundles Substrate, so this workflow adds *only* our
one dylib. It does **not** re-run cyan over the whole app (a second cyan pass
re-patches InfusePlus's own dylibs and corrupts `libswiftIU.dylib` →
"Invalid mach-o file" at sideload). Instead it copies our dylib into the app,
repoints its Substrate dependency to the bundled copy, and adds a single load
command to the main executable with LIEF. Your sideloader re-signs everything
on install.
1. In your **InfusePlus fork**, put this whole folder at the repo root as
   `InfuseControlMod/`.
2. Copy `inject-controlmod-only.yml` into `.github/workflows/`.
3. Run the **"Add ControlMod to existing IPA"** workflow with a direct-download
   URL to your existing InfusePlus IPA.
   - **Google Drive works**: paste the normal share link (e.g.
     `https://drive.google.com/file/d/…/view?usp=sharing`) and make sure the
     file is shared as **"Anyone with the link"**.
4. Install the resulting IPA with your usual sideload tool.

## Option B — build InfusePlus + ControlMod together (from a plain Infuse IPA)
1–3. Same as above, but copy `build-infuse-controlmod.yml` instead.
4. Run **"Create Infuse Plus app (+ ControlMod)"** like the normal InfusePlus
   workflow (same decrypted Infuse IPA URL, same tweak version).
5. Install the resulting IPA.

Note: the SDK step pins `iPhoneOS16.5.sdk`; if that path ever disappears it
falls back to whatever SDK is in theos/sdks. If the build errors on the SDK,
tell me and I'll pin a different one.

## Option C — build locally (Mac with Theos)
```sh
cd InfuseControlMod
make package FINALPACKAGE=1      # produces packages/com.yourname.infusecontrolmod_1.0.0_iphoneos-arm.deb
```
Then inject it into your existing InfusePlus IPA with cyan (keeps name/bundle):
```sh
cyan -i your-infuseplus.ipa -o Infuse_ControlMod.ipa -uwef packages/*.deb
```
Or, from a plain Infuse IPA, inject both at once:
```sh
cyan -i infuse.ipa -o InfusePlus.ipa -uwef infplus.deb packages/*.deb -n "Infuse" -b com.firecore.infuse
```

## If it doesn't behave
Because I can't run Infuse here, the exact trigger may need a nudge. If after
testing you see:
- **Controls still flash on autoplay** → raise `kTouchWindow` slightly, or the
  show happens on a code path other than `updateControlPanelToPlayItem:`; send
  me what you see and I'll move the hook to the control-model layer
  (`PlaybackControls_CommonModel setControlsHidden:`), which is the lower-level
  funnel I also mapped.
- **Manual "Next" now hides controls too** → lower `kTouchWindow`.
- **A normal single video opens with no controls** → make sure
  `kLeaveFirstItemAlone` is `YES`.
