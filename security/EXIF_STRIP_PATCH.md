# EXIF Strip — Copy-Paste Patch

EXIF metadata in photos can leak precise GPS coords, camera model, capture timestamp. On a faith + location app, that's a privacy issue you don't want.

The fix is one shared helper that re-encodes the image through `expo-image-manipulator`. Re-encoding to JPEG drops metadata as a side effect. No external library needed.

---

## 1. New file: `src/lib/imageSanitize.js`

```js
// ─────────────────────────────────────────────────────────────────────────
// imageSanitize.js
//
// Strips EXIF metadata (GPS, device, timestamps) from a picked image by
// re-encoding it through expo-image-manipulator. The manipulator does not
// preserve EXIF on output, so any compress/format pass effectively strips it.
//
// Use this in every upload path BEFORE handing bytes to Supabase Storage.
// ─────────────────────────────────────────────────────────────────────────

import * as ImageManipulator from 'expo-image-manipulator';

/**
 * Re-encode a picked image so EXIF is removed.
 * @param {string} uri - local file URI from expo-image-picker
 * @param {object} opts
 * @param {number} [opts.maxWidth] - downscale max width (default 2048)
 * @param {number} [opts.compress] - JPEG quality 0..1 (default 0.85)
 * @returns {Promise<{uri:string, base64:string|null, width:number, height:number}>}
 */
export async function stripExif(uri, opts = {}) {
  const { maxWidth = 2048, compress = 0.85 } = opts;
  const actions = maxWidth ? [{ resize: { width: maxWidth } }] : [];
  const result = await ImageManipulator.manipulateAsync(uri, actions, {
    compress,
    format: ImageManipulator.SaveFormat.JPEG,
    base64: true,
  });
  return {
    uri: result.uri,
    base64: result.base64 ?? null,
    width: result.width,
    height: result.height,
  };
}
```

---

## 2. Patch `src/lib/uploadAvatar.js`

**Add import** at the top with the other imports:

```js
import { stripExif } from './imageSanitize';
```

**Replace** the body of `pickImage(source)` after the `if (result.canceled) return null;` block:

```js
  if (result.canceled) return null;
  const asset = result.assets?.[0];
  if (!asset) return null;

  // Strip EXIF (GPS, device info) by re-encoding through ImageManipulator
  const sanitized = await stripExif(asset.uri, { maxWidth: 1024, compress: 0.8 });
  return { uri: sanitized.uri, base64: sanitized.base64 };
```

Avatars are square-cropped 1:1 in the picker — `maxWidth: 1024` is plenty. The base64 we pass to `decode()` is now metadata-free.

---

## 3. Patch `src/lib/profilePhotos.js`

**Add import** with the other imports:

```js
import { stripExif } from './imageSanitize';
```

**In `pickAndUploadProfilePhoto`**, find where the picker returns `asset.uri` / `asset.base64`. Before the `decode(base64)` / upload call, route through `stripExif`:

```js
const sanitized = await stripExif(asset.uri, { maxWidth: 2048, compress: 0.85 });
const base64 = sanitized.base64;
// ...rest of the upload uses `base64` as before
```

---

## 4. Patch `src/lib/groupPhotos.js` and `src/lib/groupPosts.js`

Same pattern — find where the picker returns the asset, replace with:

```js
const sanitized = await stripExif(asset.uri, { maxWidth: 2048, compress: 0.85 });
const base64 = sanitized.base64;
```

If those files read base64 differently (e.g., via `FileSystem.readAsStringAsync`), point that read at `sanitized.uri` instead of the raw picker URI.

---

## 5. Verify

Quick smoke test after rebuild:

1. Take a photo outdoors with location services on.
2. Upload as avatar / profile photo.
3. Download the file from Supabase Storage to your laptop.
4. Run `exiftool downloaded.jpg` (or open in Preview → Inspector on Mac).
5. Should see only basic dimensions / encoding — no `GPSLatitude`, no `Make/Model`, no `DateTimeOriginal`.

If you don't have exiftool: `brew install exiftool`.

---

## 6. Dependency

```bash
npx expo install expo-image-manipulator
```

You probably already have it (Expo SDK includes it as a peer of image-picker), but pin it explicitly to be safe.
