# Character Layer Assets

This app prefers layered transparent PNG sprites.

All layers for one character must use:

- the same canvas size
- the same origin
- transparent background
- PNG format

Recommended model specs:

- Use transparent PNG files in sRGB.
- Use lowercase ASCII names with underscores.
- Keep all layers for one character on the exact same canvas.
- Recommended standing character height is 1600-2400 px.
- Recommended plush character height is 1000-1600 px.
- Leave 8-12% transparent padding so hands and emotion icons are not clipped.
- Keep each PNG under 5 MB when possible.
- The app composites layers in this order: base, hand, face, icon.
- Runtime model packs can use the same folder structure outside the app bundle and be selected in Settings.

## Girl Character

```text
character_a/base.png
character_a/face_happy.png
character_a/face_angry.png
character_a/face_sad.png
character_a/face_fun.png
character_a/face_sleep.png
character_a/hand_default.png
character_a/hand_wave.png
character_a/hand_point.png
character_a/hand_think.png
character_a/hand_emphasize.png
character_a/hand_sleep.png
character_a/icon_happy.png
character_a/icon_angry.png
character_a/icon_sad.png
character_a/icon_fun.png
character_a/icon_sleep.png
```

## Plush Character

Use the happy seated pose as `character_b/base.png`.

```text
character_b/base.png
character_b/face_happy.png
character_b/face_angry.png
character_b/face_sad.png
character_b/face_sleep.png
character_b/icon_sad.png
character_b/icon_sleep.png
```

For the plush character, keep the bottle-bottom glasses and seated pose fixed. Use only mouth, eyebrows, tears, and small icons for expression.
