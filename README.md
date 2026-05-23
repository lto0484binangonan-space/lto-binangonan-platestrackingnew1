# LTO Binangonan Plate Tracker — Deployment Guide
## Netlify + Supabase (Free Tier)

---

## OVERVIEW

| Layer      | Service   | Cost  |
|------------|-----------|-------|
| Frontend   | Netlify   | Free  |
| Database   | Supabase  | Free  |
| Auth       | Supabase  | Free  |
| Domain     | Netlify subdomain | Free |

---

## STEP 1 — Set Up Supabase (Database + Auth)

### 1a. Create a Supabase account and project
1. Go to **https://supabase.com** → click **Start your project**
2. Sign up (GitHub login is fastest)
3. Click **New Project**
   - Organization: create one (e.g. "LTO Binangonan")
   - Name: `lto-plate-tracker`
   - Database Password: set a strong password and **save it somewhere**
   - Region: `Southeast Asia (Singapore)` — closest to Philippines
4. Click **Create new project** and wait ~2 minutes

### 1b. Run the database migration
1. In your Supabase project, click **SQL Editor** in the left sidebar
2. Click **+ New query**
3. Open the file `supabase/migrations/001_initial_schema.sql` from this project
4. Paste the entire contents into the SQL editor
5. Click **Run** (▶ button)
6. You should see "Success. No rows returned."

### 1c. Create the first Super Admin account
1. In Supabase → left sidebar → **Authentication** → **Users**
2. Click **Invite user** (top right)
3. Enter the admin email (e.g. `admin@lto-binangonan.gov.ph`)
4. They'll receive an email invite; OR click **Add user** → **Create new user**
   and set a password directly
5. After the user is created, copy their **User UID** (the long UUID in the Users list)
6. Go back to **SQL Editor** → New query, and run:
   ```sql
   INSERT INTO public.admin_profiles (id, username, full_name, role)
   VALUES (
     'PASTE-THE-UUID-HERE',
     'admin',
     'System Administrator',
     'superadmin'
   );
   ```
   Replace `PASTE-THE-UUID-HERE` with the actual UUID.

### 1d. Get your API credentials
1. In Supabase → left sidebar → **Project Settings** (gear icon) → **API**
2. Copy two values:
   - **Project URL** → looks like `https://abcdefgh.supabase.co`
   - **anon public key** → long string starting with `eyJ...`
3. Keep these ready for Step 3.

---

## STEP 2 — Set Up GitHub Repository

### 2a. Install prerequisites (one-time)
- Install **Node.js** (v18+): https://nodejs.org
- Install **Git**: https://git-scm.com

### 2b. Prepare the project
```bash
# Navigate to the project folder (this folder)
cd lto-tracker

# Copy the environment file
cp .env.example .env.local

# Edit .env.local with your Supabase credentials:
# REACT_APP_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
# REACT_APP_SUPABASE_ANON_KEY=your_anon_key_here

# Install dependencies
npm install

# Test locally first
npm start
# → Opens http://localhost:3000
# → Try searching a plate (ABC123, DEF901, etc.)
# → Click Admin → log in with the credentials you created
```

### 2c. Create a GitHub repo and push
```bash
git init
git add .
git commit -m "Initial LTO plate tracker"

# Create a GitHub account at https://github.com if you don't have one
# Then create a new repository named "lto-plate-tracker" (public or private)

git remote add origin https://github.com/YOUR-USERNAME/lto-plate-tracker.git
git branch -M main
git push -u origin main
```

---

## STEP 3 — Deploy to Netlify

### 3a. Create a Netlify account
1. Go to **https://netlify.com** → Sign up (GitHub login is fastest)

### 3b. Connect your repository
1. Click **Add new site** → **Import an existing project**
2. Choose **GitHub** → authorize Netlify
3. Select your `lto-plate-tracker` repository
4. Build settings (should auto-detect):
   - **Build command:** `npm run build`
   - **Publish directory:** `build`
5. **DO NOT click Deploy yet** — you need to add env vars first

### 3c. Add environment variables
1. Scroll down to **Environment variables**
2. Add:
   - Key: `REACT_APP_SUPABASE_URL`
     Value: your Supabase project URL
   - Key: `REACT_APP_SUPABASE_ANON_KEY`
     Value: your Supabase anon key
3. Now click **Deploy site**

### 3d. Get your live URL
- Netlify gives you a URL like `https://random-words-123.netlify.app`
- To customize it: **Site settings** → **Domain management** → **Options** → **Edit site name**
- Set it to something like `lto-binangonan` → your URL becomes `https://lto-binangonan.netlify.app`

---

## STEP 4 — Custom Domain (Optional)

If LTO Binangonan has a domain (e.g. `lto-binangonan.gov.ph`):

1. In Netlify → **Site settings** → **Domain management** → **Add custom domain**
2. Enter your domain
3. Update your DNS records at your domain registrar:
   - Add a **CNAME record**: `plates` → `your-site.netlify.app`
   - This gives you `plates.lto-binangonan.gov.ph`
4. Netlify provides free HTTPS/SSL automatically

---

## STEP 5 — Verify Everything Works

1. Open your live URL (e.g. `https://lto-binangonan.netlify.app`)
2. Search for plate `ABC123` — should show "Available for Claiming"
3. Click **Admin** → log in with your admin email/password
4. Try adding a plate, editing, marking as claimed with signature + photo
5. Open an incognito window and search for the newly claimed plate — you should see the updated status

---

## UPDATING THE SYSTEM

Any time you push a code change to GitHub, Netlify auto-redeploys:
```bash
git add .
git commit -m "describe your change"
git push
```
Netlify picks it up in ~1-2 minutes.

---

## ADDING MORE ADMIN ACCOUNTS

Option A — Supabase Dashboard (easiest):
1. Supabase → Authentication → Users → Invite user
2. Enter their email; they receive a magic link
3. After they accept, go to SQL Editor and run:
   ```sql
   INSERT INTO public.admin_profiles (id, username, full_name, role)
   VALUES ('<their-uuid>', 'officer2', 'Officer Name', 'admin');
   ```

Option B — From the Admin panel in the app (Super Admin only):
- Uses the Supabase Admin API; requires the service role key on a backend.
  For a simple setup, use Option A via the dashboard.

---

## TROUBLESHOOTING

| Problem | Fix |
|---------|-----|
| Blank page on Netlify | Check env vars are set in Netlify dashboard |
| "Missing Supabase env vars" in console | Add vars to .env.local (local) or Netlify settings (live) |
| Login fails "Account not found" | Run the INSERT for admin_profiles with the correct UUID |
| Plates not loading | Check Supabase → Table Editor → plates table exists and has data |
| RLS error in Supabase logs | Re-run the migration SQL to ensure all policies are created |

---

## SECURITY NOTES

- The `anon` key is safe to expose in frontend code — it's designed for that.
  Supabase RLS (Row Level Security) policies control what it can access.
- Admins log in via Supabase Auth — passwords are never stored in your code.
- The `service_role` key (shown in Supabase → Settings → API) must NEVER
  be put in frontend code. Only use it in a secure backend/serverless function.
- Enable **2FA** on your Supabase account for extra security.

---

## FREE TIER LIMITS (more than enough for LTO Binangonan)

| Resource        | Free Limit        |
|-----------------|-------------------|
| Database        | 500 MB            |
| Auth users      | 50,000            |
| API requests    | 2 million/month   |
| Netlify builds  | 300 min/month     |
| Netlify bandwidth | 100 GB/month    |

---

*Generated for LTO Binangonan Extension Office — Plate Tracker v2.0*
