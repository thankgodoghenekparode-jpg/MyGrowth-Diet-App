# Offline Bible translations

The app includes three complete, offline English Bible texts:

- `web.json` — World English Bible (WEB), 66-book Protestant edition.
- `bsb.json` — Berean Standard Bible (BSB), public domain. Attribution is appreciated: "The Holy Bible, Berean Standard Bible, BSB."
- `kjv.json` — King James Version (KJV), 1769 standardized text, 66-book Protestant canon. eBible.org notes that the KJV is public domain outside the United Kingdom; UK publication/import restrictions may apply.

The WEB and BSB are from eBible.org VPL archives `engwebp_vpl.zip` and `engbsb_vpl.zip`. The KJV is from `eng-kjv2006_vpl.zip`. Source and status pages:

- WEB: https://ebible.org/find/details.php?id=engwebp
- BSB: https://ebible.org/find/details.php?id=engbsb
- KJV: https://ebible.org/find/details.php?id=eng-kjv2006

To regenerate a JSON asset, download the matching VPL archive from https://ebible.org/Scriptures/ into this directory and run from the Flutter app directory:

```sh
node scripts/build_web_bible.cjs web
node scripts/build_web_bible.cjs bsb
node scripts/build_web_bible.cjs kjv
```

The builder preserves each archive's verse wording and builds the same 66-book structure for the reader. Copyrighted translations such as The Message are not bundled here; they require permission from the publisher and a delivery method allowed by that license.
