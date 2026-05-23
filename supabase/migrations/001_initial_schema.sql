-- ============================================================
-- LTO Binangonan Plate Tracker — Supabase Migration
-- Run this in: Supabase Dashboard → SQL Editor → New Query
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
  -- Claim fields (populated when status = 'Claimed')
  received_by       text,
  claimed_at        timestamptz,
  released_by       text,
  signature_data    text,   -- base64 PNG
  photo_data        text,   -- base64 JPEG
  drive_file_id     text,
  drive_file_name   text,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- ── 2. ADMIN ACCOUNTS table ──────────────────────────────────
-- Uses Supabase Auth (auth.users) for actual login.
-- This table stores the display profile + role.
CREATE TABLE IF NOT EXISTS public.admin_profiles (
  id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username    text NOT NULL UNIQUE,
  full_name   text NOT NULL DEFAULT '',
  role        text NOT NULL DEFAULT 'admin'
              CHECK (role IN ('admin','superadmin')),
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ── 3. Row Level Security ─────────────────────────────────────
ALTER TABLE public.plates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_profiles ENABLE ROW LEVEL SECURITY;

-- Public: read-only access to plates (for the public tracker)
CREATE POLICY "Public can read plates"
  ON public.plates FOR SELECT
  USING (true);

-- Authenticated admins: full CRUD on plates
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

-- Admin profiles: each admin sees their own profile; superadmins see all
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

-- ── 4. Helper: auto-update last_updated ──────────────────────
CREATE OR REPLACE FUNCTION public.set_last_updated()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.last_updated = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER plates_set_last_updated
  BEFORE UPDATE ON public.plates
  FOR EACH ROW EXECUTE FUNCTION public.set_last_updated();

-- ── 5. Seed sample plates ─────────────────────────────────────
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

-- ── 6. IMPORTANT: Create the first Super Admin account ────────
-- After running this migration:
-- 1. Go to Supabase → Authentication → Users → "Invite User"
--    OR run: supabase auth admin create-user (CLI)
-- 2. Use email: admin@lto-binangonan.gov.ph  password: (set your own)
-- 3. Copy the user UUID from the Users list, then run:
--
-- INSERT INTO public.admin_profiles (id, username, full_name, role)
-- VALUES ('<PASTE-UUID-HERE>', 'admin', 'System Administrator', 'superadmin');
--
-- ── Done! ─────────────────────────────────────────────────────
