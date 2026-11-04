$root = "C:\Users\USER\Desktop\MyGrowth Diet Plan"
Set-Location "$root\Frontend\mygrowth_app"
flutter build web --release --dart-define=API_BASE_URL=https://mygrowth-diet-app.onrender.com/api/v1
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed"; exit 1 }

Set-Location $root
Remove-Item -Recurse -Force web-deploy\* -ErrorAction SilentlyContinue
Copy-Item "Frontend\mygrowth_app\build\web\*" web-deploy -Recurse -Force
Set-Content -Path web-deploy\vercel.json -Value '{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }'

git add .
git status
