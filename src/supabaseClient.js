import { createClient } from '@supabase/supabase-js';

const supabaseUrl  = process.env.REACT_APP_SUPABASE_URL;
const supabaseKey  = process.env.REACT_APP_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error(
    '[LTO Tracker] Missing Supabase env vars.\n' +
    'Copy .env.example → .env.local and fill in your project credentials.'
  );
}

export const supabase = createClient(supabaseUrl, supabaseKey);
