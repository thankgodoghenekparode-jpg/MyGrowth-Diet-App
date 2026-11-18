# Regenerates the splash animation from the source video.
#
# The splash artwork has no background of its own: the near-white backdrop of
# the source clip is keyed out so the animation sits straight on the app
# wallpaper in both light and dark mode.
#
#   powershell -File scripts/make-splash-animation.ps1
#
# Requires ffmpeg on PATH (or pass -Ffmpeg with a full path).

param(
  [string]$Source = (Join-Path $PSScriptRoot '..\Frontend\mygrowth_app\assets\source\splash_source.mp4'),
  [string]$Target = (Join-Path $PSScriptRoot '..\Frontend\mygrowth_app\assets\images\splash_anim.webp'),
  [string]$Ffmpeg = 'ffmpeg'
)

$Source = (Resolve-Path $Source).Path
$Target = [System.IO.Path]::GetFullPath($Target)

# hqdn3d            calms the clip's compression noise so the key is stable
# colorkey          turns the near-white backdrop transparent, with a short
#                   blend band so the artwork's soft edges stay anti-aliased
# geq               changes only bright cyan-blue pixels to white, leaving the
#                   dark navy logo unchanged and preserving the keyed alpha
# libwebp_anim      animated WebP with an alpha channel
$whiteMovingLight = "geq=r='if(gt(g(X,Y)-r(X,Y),12)*gt(b(X,Y)-r(X,Y),24)*gt(r(X,Y)+g(X,Y)+b(X,Y),540),255,r(X,Y))':g='if(gt(g(X,Y)-r(X,Y),12)*gt(b(X,Y)-r(X,Y),24)*gt(r(X,Y)+g(X,Y)+b(X,Y),540),255,g(X,Y))':b='if(gt(g(X,Y)-r(X,Y),12)*gt(b(X,Y)-r(X,Y),24)*gt(r(X,Y)+g(X,Y)+b(X,Y),540),255,b(X,Y))':a='alpha(X,Y)'"
$videoFilter = "hqdn3d=8:6:12:8,format=rgba,colorkey=0xF5F5F5:0.09:0.02,$whiteMovingLight"

# -loop 1           play once and hold the last frame (0 would loop forever)
& $Ffmpeg -hide_banner -y -i $Source `
  -vf $videoFilter `
  -c:v libwebp_anim -quality 90 -loop 1 -an $Target

if ($LASTEXITCODE -ne 0) {
  throw "ffmpeg failed with exit code $LASTEXITCODE"
}

$file = Get-Item $Target
Write-Host ("Wrote {0} ({1:N0} bytes)" -f $file.FullName, $file.Length)
