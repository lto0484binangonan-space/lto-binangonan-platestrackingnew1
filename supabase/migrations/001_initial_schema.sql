-- ============================================================
-- LTO Binangonan Plate Tracker — Safe Re-runnable Migration
-- Run this in: Supabase Dashboard → SQL Editor → New Query
-- Safe to run multiple times — drops existing policies first
-- ============================================================

-- ── 1. PLATES table ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.plates (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plate_number      text NOT NULL UNIQUE,
  vehicle_type      text NOT NULL DEFAULT '',
  applicant_name    text NOT NULL DEFAULT '',
  applicant_email   text NOT NULL DEFAULT '',
  date_applied      date,
  mv_file_no        text NOT NULL DEFAULT '',
  classification    text NOT NULL DEFAULT 'Private',
  region            text NOT NULL DEFAULT 'Region IV-A (CALABARZON)',
  status            text NOT NULL DEFAULT 'Received'
                    CHECK (status IN ('Received','Available for Claiming','Claimed')),
  last_updated      timestamptz NOT NULL DEFAULT now(),
  received_by       text,
  claimed_at        timestamptz,
  released_by       text,
  signature_data    text,
  photo_data        text,
  drive_file_id     text,
  drive_file_name   text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- ── 2. ADMIN PROFILES table ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.admin_profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username    text NOT NULL UNIQUE,
  full_name   text NOT NULL DEFAULT '',
  role        text NOT NULL DEFAULT 'admin'
              CHECK (role IN ('admin','superadmin')),
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ── 3. Enable RLS ─────────────────────────────────────────────
ALTER TABLE public.plates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;

-- ── 4. Drop existing policies first (safe to re-run) ──────────
DROP POLICY IF EXISTS "Public can read plates"          ON public.plates;
DROP POLICY IF EXISTS "Admins can insert plates"        ON public.plates;
DROP POLICY IF EXISTS "Admins can update plates"        ON public.plates;
DROP POLICY IF EXISTS "Admins can delete plates"        ON public.plates;
DROP POLICY IF EXISTS "Admins read own profile"         ON public.admin_profiles;
DROP POLICY IF EXISTS "Superadmins manage all profiles" ON public.admin_profiles;

-- ── 5. Recreate all policies ──────────────────────────────────
CREATE POLICY "Public can read plates"
  ON public.plates FOR SELECT
  USING (true);

CREATE POLICY "Admins can insert plates"
  ON public.plates FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "Admins can update plates"
  ON public.plates FOR UPDATE
  TO authenticated
  USING (true);

CREATE POLICY "Admins can delete plates"
  ON public.plates FOR DELETE
  TO authenticated
  USING (true);

CREATE POLICY "Admins read own profile"
  ON public.admin_profiles FOR SELECT
  TO authenticated
  USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.admin_profiles p
      WHERE p.id = auth.uid() AND p.role = 'superadmin'
    )
  );

CREATE POLICY "Superadmins manage all profiles"
  ON public.admin_profiles FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_profiles p
      WHERE p.id = auth.uid() AND p.role = 'superadmin'
    )
  );

-- ── 6. Auto-update last_updated trigger ───────────────────────
CREATE OR REPLACE FUNCTION public.set_last_updated()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.last_updated = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS plates_set_last_updated ON public.plates;

CREATE TRIGGER plates_set_last_updated
  BEFORE UPDATE ON public.plates
  FOR EACH ROW EXECUTE FUNCTION public.set_last_updated();

-- ── 7. Seed sample plates (skips duplicates) ──────────────────
INSERT INTO public.plates
  (plate_number, vehicle_type, applicant_name, applicant_email, date_applied,
   mv_file_no, classification, region, status)
VALUES
  ('ABC123','Sedan',       'Juan D***',  'juan.d@example.com',  '2025-04-01','MV-2025-00421','Private',       'Region IV-A (CALABARZON)','Available for Claiming'),
  ('XYZ567','SUV',         'Maria S***', 'maria.s@example.com', '2025-03-15','MV-2025-00318','Private',       'Region IV-A (CALABARZON)','Claimed'),
  ('DEF901','Motorcycle',  'Pedro R***', 'pedro.r@example.com', '2025-04-20','MV-2025-00512','Private',       'Region IV-A (CALABARZON)','Received'),
  ('GHI345','Pickup Truck','Rosa M***',  'rosa.m@example.com',  '2025-04-25','MV-2025-00560','Private',       'Region IV-A (CALABARZON)','Received'),
  ('JKL678','Van',         'Carlo T***', 'carlo.t@example.com', '2025-03-28','MV-2025-00399','Commercial',    'Region IV-A (CALABARZON)','Available for Claiming'),
  ('NCR789','Jeepney',     'Lito B***',  'lito.b@example.com',  '2025-02-10','MV-2025-00201','Public Utility','Region IV-A (CALABARZON)','Claimed')
ON CONFLICT (plate_number) DO NOTHING;

-- ── 8. Done! Create your first Super Admin ────────────────────
-- Go to: Supabase → Authentication → Users → Add user → Create new user
-- Copy the UUID shown, then run this (replace the UUID):
--
-- INSERT INTO public.admin_profiles (id, username, full_name, role)
-- VALUES ('<PASTE-UUID-HERE>', 'admin', 'System Administrator', 'superadmin');
