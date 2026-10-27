# World English Bible asset

`web.json` contains the 66-book Protestant edition of the World English Bible
(WEB), converted from eBible.org's `engwebp_vpl.zip` verse-per-line archive.
The text is faithful to the source; only the surrounding archive formatting was
removed to create the JSON data structure.

eBible.org dedicates the World English Bible to the public domain. The name
“World English Bible” is a trademark and identifies faithful copies of the
translation. Source and license: <https://ebible.org/find/details.php?id=engwebp>.

To regenerate the asset, download
<https://ebible.org/Scriptures/engwebp_vpl.zip> to this folder and run
`node scripts/build_web_bible.cjs` from the Flutter app directory.
