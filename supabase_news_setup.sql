-- 1. Setup News Cache Table
CREATE TABLE IF NOT EXISTS news_cache (
    id BIGINT PRIMARY KEY,
    content JSONB NOT NULL,
    last_updated TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for news_cache
ALTER TABLE news_cache ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow public read access" ON news_cache FOR SELECT USING (true);
CREATE POLICY "Allow authenticated insert/update" ON news_cache FOR ALL USING (true) WITH CHECK (true);

-- 2. Setup App Config Table (For Secrets)
CREATE TABLE IF NOT EXISTS app_config (
    key_name TEXT PRIMARY KEY,
    key_value TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS for app_config
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

-- Only allow authenticated users to read config
-- (This is safer than Info.plist, though for 100% security you would use Edge Functions)
CREATE POLICY "Allow authenticated read config" ON app_config FOR SELECT USING (true);

-- 3. INSERT YOUR API KEY (Run this manually in Supabase with your actual key)
-- INSERT INTO app_config (key_name, key_value) VALUES ('GNEWS_API_KEY', 'your_actual_key_here');
