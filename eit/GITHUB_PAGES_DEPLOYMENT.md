# Deploy E-Learning IT to GitHub Pages

## Architecture Overview
- **Frontend (Flutter Web)**: GitHub Pages (https://trieupham1.github.io/Elearning_IT/)
- **Backend (Node.js/Express)**: Render (https://elearning-it.onrender.com)

## Step-by-Step Deployment Guide

### Step 1: Enable GitHub Pages in Repository Settings

1. Go to your GitHub repository: https://github.com/trieupham1/Elearning_IT
2. Click on **Settings** tab
3. Scroll down to **Pages** section (left sidebar)
4. Under "Build and deployment":
   - Source: Select **GitHub Actions**
5. Click **Save**

### Step 2: Push the Changes

```powershell
# Navigate to project directory
cd d:\flutter\final_project\Elearning_IT\eit

# Stage the new workflow file and updated config
git add .github/workflows/deploy-web.yml
git add lib/config/api_config.dart

# Commit the changes
git commit -m "Add GitHub Pages deployment workflow"

# Push to GitHub
git push origin main
```

### Step 3: Monitor Deployment

1. Go to your repository on GitHub
2. Click the **Actions** tab
3. You'll see "Deploy Flutter Web to GitHub Pages" workflow running
4. Wait for it to complete (usually 2-5 minutes)
5. Once complete, your site will be live at:
   **https://trieupham1.github.io/Elearning_IT/**

### Step 4: Test the Deployed App

1. Open: https://trieupham1.github.io/Elearning_IT/
2. The web app should load and connect to your Render backend
3. Test login with your credentials

---

## Troubleshooting

### If deployment fails:
- Check the Actions tab for error messages
- Ensure Flutter version in workflow matches your local version
- Verify GitHub Pages is enabled in repository settings

### If app loads but API fails:
- Check that backend on Render is running
- Verify CORS settings in backend allow requests from GitHub Pages domain
- Check browser console for errors (F12)

### Update the base href if needed:
The workflow uses `--base-href /Elearning_IT/` because your repo is named "Elearning_IT". If you see routing issues, this is the setting to adjust.

---

## Manual Deployment (Alternative)

If you prefer to deploy manually without GitHub Actions:

```powershell
# Build the web app
cd d:\flutter\final_project\Elearning_IT\eit
flutter build web --release --base-href /Elearning_IT/

# Install gh-pages package globally (one time only)
npm install -g gh-pages

# Deploy to GitHub Pages
gh-pages -d build/web
```

---

## Updating the Deployment

Every time you push changes to `lib/**`, `web/**`, or `pubspec.yaml` on the main branch, the workflow will automatically rebuild and redeploy your site.

To manually trigger deployment:
1. Go to Actions tab
2. Click "Deploy Flutter Web to GitHub Pages"
3. Click "Run workflow"
4. Select branch "main"
5. Click "Run workflow"

---

## Important Notes

1. **Backend stays on Render** - Only the frontend is on GitHub Pages
2. **Free GitHub Pages limits**:
   - 1GB storage
   - 100GB bandwidth/month
   - 10 builds/hour

3. **CORS Configuration** - Make sure your backend allows requests from GitHub Pages domain. Check `backend/server.js` CORS settings.

4. **Environment Differences**:
   - Web (GitHub Pages): Uses production backend URL
   - Desktop/Mobile development: Uses localhost backend
   - Android emulator: Uses 10.0.2.2 backend

---

## What's Next?

1. Push the changes to GitHub
2. Enable GitHub Pages in settings
3. Wait for deployment
4. Access your app at: https://trieupham1.github.io/Elearning_IT/

Your E-Learning system will be publicly accessible! 🚀
