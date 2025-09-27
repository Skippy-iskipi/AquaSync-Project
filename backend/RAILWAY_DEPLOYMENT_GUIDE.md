# Railway Deployment Guide for AquaSync Backend

This guide will help you deploy your FastAPI backend to Railway step by step.

## Prerequisites

Before deploying, make sure you have:
1. A Railway account (sign up at [railway.app](https://railway.app))
2. Your Supabase project set up with all required tables
3. Your environment variables ready
4. A GitHub repository with your code

## Step-by-Step Deployment

### Step 1: Prepare Your Repository

1. **Ensure your project structure is correct:**
   ```
   backend/
   ├── app/
   │   ├── main.py
   │   ├── supabase_config.py
   │   └── ... (other modules)
   ├── requirements.txt
   ├── runtime.txt
   ├── Procfile
   ├── railway.toml
   └── railway.env.example
   ```

2. **Commit all changes to your repository:**
   ```bash
   git add .
   git commit -m "Add Railway deployment configuration"
   git push origin main
   ```

### Step 2: Create Railway Project

1. **Go to Railway Dashboard:**
   - Visit [railway.app](https://railway.app)
   - Sign in to your account

2. **Create New Project:**
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your repository
   - Select the `backend` folder as the root directory

### Step 3: Configure Environment Variables

1. **In your Railway project dashboard:**
   - Go to your service
   - Click on "Variables" tab
   - Add the following environment variables:

   ```
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
   OPENAI_API_KEY=your_openai_api_key
   MODEL_CACHE_DIR=/tmp/model_cache
   ENVIRONMENT=production
   ```

2. **Get your Supabase credentials:**
   - Go to your Supabase project dashboard
   - Go to Settings > API
   - Copy the Project URL and Service Role Key

3. **Get your OpenAI API key:**
   - Go to [OpenAI API Keys](https://platform.openai.com/api-keys)
   - Create a new API key if you don't have one

### Step 4: Deploy

1. **Trigger deployment:**
   - Railway will automatically deploy when you push to your main branch
   - Or you can manually trigger a deployment from the dashboard

2. **Monitor the deployment:**
   - Watch the deployment logs in Railway dashboard
   - Check for any errors during the build process

### Step 5: Test Your Deployment

1. **Get your Railway URL:**
   - After successful deployment, Railway will provide you with a URL
   - It will look like: `https://your-app-name-production.up.railway.app`

2. **Test the health endpoint:**
   ```
   GET https://your-app-name-production.up.railway.app/health
   ```

3. **Test other endpoints:**
   ```
   GET https://your-app-name-production.up.railway.app/
   GET https://your-app-name-production.up.railway.app/docs
   ```

## Important Notes

### Memory and Resource Considerations

Your FastAPI app uses machine learning models which can be memory-intensive:

1. **Railway Plan Requirements:**
   - The free tier has limited memory (512MB)
   - Consider upgrading to a paid plan for better performance
   - The Pro plan offers 8GB RAM which should be sufficient

2. **Model Loading Optimization:**
   - Models are loaded in the background on startup
   - The app includes memory monitoring and optimization
   - Large models are cached to reduce memory usage

### Environment-Specific Configurations

1. **Production Settings:**
   - CORS is configured to allow all origins (`*`)
   - Consider restricting this to your frontend domain in production
   - All sensitive data should be in environment variables

2. **Database Connection:**
   - Uses Supabase for database operations
   - Service role key is used for backend operations
   - Connection is verified on startup

### Troubleshooting

#### Common Issues:

1. **Build Failures:**
   - Check that all dependencies are in `requirements.txt`
   - Ensure Python version is specified in `runtime.txt`
   - Check build logs for specific error messages

2. **Runtime Errors:**
   - Verify all environment variables are set correctly
   - Check application logs in Railway dashboard
   - Ensure Supabase connection is working

3. **Memory Issues:**
   - Monitor memory usage in Railway dashboard
   - Consider upgrading to a higher plan
   - Check if models are loading properly

4. **CORS Issues:**
   - Update CORS settings if deploying to a custom domain
   - Ensure frontend is pointing to the correct Railway URL

### Performance Optimization

1. **Model Caching:**
   - Models are cached in `/tmp/model_cache` on Railway
   - This reduces startup time on subsequent deployments

2. **Background Loading:**
   - Models load in the background to avoid blocking the app
   - Health check endpoint shows model loading status

3. **Memory Management:**
   - App includes garbage collection and memory monitoring
   - Thread pool is limited to reduce memory usage

## Custom Domain (Optional)

If you want to use a custom domain:

1. **In Railway Dashboard:**
   - Go to your service
   - Click on "Settings"
   - Go to "Domains"
   - Add your custom domain

2. **Update Environment Variables:**
   - Add `CUSTOM_DOMAIN=your-domain.com`

3. **Update CORS Settings:**
   - Modify the CORS middleware in `main.py` to allow your domain

## Monitoring and Maintenance

1. **Railway Dashboard:**
   - Monitor deployment status
   - Check resource usage
   - View application logs

2. **Health Monitoring:**
   - Use the `/health` endpoint for health checks
   - Monitor model loading status
   - Check memory usage

3. **Updates:**
   - Push changes to your main branch to trigger automatic deployments
   - Monitor deployment logs for any issues

## Security Considerations

1. **Environment Variables:**
   - Never commit sensitive data to your repository
   - Use Railway's environment variables for all secrets

2. **API Keys:**
   - Rotate API keys regularly
   - Use service-specific keys where possible

3. **Database Security:**
   - Use Supabase's Row Level Security (RLS)
   - Service role key should only be used by the backend

## Support

If you encounter issues:

1. **Check Railway Documentation:** [docs.railway.app](https://docs.railway.app)
2. **Railway Community:** [discord.gg/railway](https://discord.gg/railway)
3. **Application Logs:** Check the logs section in your Railway dashboard

## Next Steps

After successful deployment:

1. **Update your frontend** to use the Railway URL
2. **Test all API endpoints** thoroughly
3. **Set up monitoring** and alerts
4. **Configure backups** for your Supabase database
5. **Set up CI/CD** for automatic deployments

---

**Congratulations!** Your AquaSync backend should now be successfully deployed on Railway! 🚀
