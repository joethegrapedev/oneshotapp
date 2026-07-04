# Play Store assets

Brand-styled assets for the Google Play listing. Generated from the One Shot
mark (terracotta arch + dot on paper `#FBF7F0`) — the same mark used by the
Android adaptive launcher icon (`android/app/src/main/res/drawable/ic_launcher_foreground.xml`).

| File | Size | Play Console field | Required |
|------|------|--------------------|----------|
| `icon-512.png` | 512×512 | App icon (high-res) | yes |
| `feature-1024x500.png` | 1024×500 | Feature graphic | yes |
| `mark.png` | 300×300 | (intermediate, used to build the graphic) | no |

## Regenerate

```bash
bash store/build_store_assets.sh
```

Requires ImageMagick 7 (`magick`). The mark is drawn with native ImageMagick
path ops (not SVG rendering) because IM's built-in SVG renderer drops stroked
`fill:none` paths. `mark.svg` / `icon-512.svg` are kept as the design reference.

## Notes

- These are a clean, on-brand **first pass**. Swap in a bespoke icon anytime by
  replacing the PNGs (keep the same filenames/sizes) — no code depends on them.
- The launcher icon is an adaptive vector, so the app already ships a matching
  icon on-device; these files are only for the store listing.
- Screenshots (2–8 phone screenshots) are still needed for the listing and must
  come from the running app — capture them during the build/QA pass.
