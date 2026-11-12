param(
  [string]$Message = "update",
  [switch]$SkipFrontend
)

$root = "C:\Users\USER\Desktop\MyGrowth Diet Plan"

if (-not $SkipFrontend) {
  Set-Location "$root\Frontend\mygrowth_app"
  flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings
  if ($LASTEXITCODE -ne 0) { Write-Host "Analyze found errors. Fix them first."; exit 1 }

  flutter build web --no-pub --release --dart-define=API_BASE_URL=https://mygrowth-diet-app.onrender.com/api/v1
  if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

  Set-Location $root
  Remove-Item -Recurse -Force web-deploy\* -ErrorAction SilentlyContinue
  Copy-Item "Frontend\mygrowth_app\build\web\*" web-deploy -Recurse -Force
  Set-Content -Path web-deploy\vercel.json -Value '{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }'
}

Set-Location $root
git add .

$staged = git diff --cached --name-only
if (-not $staged) { Write-Host "Nothing to commit."; exit 0 }

if ($staged | Select-String -Pattern '(^|/)\.env$') {
  Write-Host "A plain .env file is staged. Aborting."
  git reset
  exit 1
}

git commit -m $Message
git push
if ($LASTEXITCODE -ne 0) { Write-Host 'PUSH FAILED. Run git push again.'; exit 1 }
Write-Host 'Done. Vercel and Render are redeploying.'

