-- BBangWay v2 Schema
-- Supabase SQL Editor에서 실행하세요
-- https://supabase.com/dashboard/project/xxkqyoduesuzvhuqxvnl

-- ────────────────────────────────────────────────
-- 테이블 생성
-- ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS stores (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name        TEXT        NOT NULL,
  code        TEXT        UNIQUE NOT NULL,
  description TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS categories (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id   UUID        REFERENCES stores(id) ON DELETE CASCADE NOT NULL,
  name       TEXT        NOT NULL,
  sort_order INTEGER     NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS breads (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    UUID        REFERENCES stores(id) ON DELETE CASCADE NOT NULL,
  category_id UUID        REFERENCES categories(id) ON DELETE SET NULL,
  name        TEXT        NOT NULL,
  price       INTEGER,
  description TEXT,
  glb_url     TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bread_photos (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  bread_id   UUID        REFERENCES breads(id) ON DELETE CASCADE NOT NULL,
  photo_url  TEXT        NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ────────────────────────────────────────────────
-- Row Level Security
-- ────────────────────────────────────────────────

ALTER TABLE stores      ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories  ENABLE ROW LEVEL SECURITY;
ALTER TABLE breads      ENABLE ROW LEVEL SECURITY;
ALTER TABLE bread_photos ENABLE ROW LEVEL SECURITY;

-- stores
CREATE POLICY "owner_manage_store"  ON stores FOR ALL    USING (auth.uid() = owner_id);
CREATE POLICY "public_read_stores"  ON stores FOR SELECT USING (true);

-- categories
CREATE POLICY "owner_manage_categories" ON categories FOR ALL USING (
  EXISTS (SELECT 1 FROM stores WHERE id = categories.store_id AND owner_id = auth.uid())
);
CREATE POLICY "public_read_categories" ON categories FOR SELECT USING (true);

-- breads
CREATE POLICY "owner_manage_breads" ON breads FOR ALL USING (
  EXISTS (SELECT 1 FROM stores WHERE id = breads.store_id AND owner_id = auth.uid())
);
CREATE POLICY "public_read_breads" ON breads FOR SELECT USING (true);

-- bread_photos
CREATE POLICY "owner_manage_photos" ON bread_photos FOR ALL USING (
  EXISTS (
    SELECT 1 FROM breads b JOIN stores s ON s.id = b.store_id
    WHERE b.id = bread_photos.bread_id AND s.owner_id = auth.uid()
  )
);
CREATE POLICY "public_read_photos" ON bread_photos FOR SELECT USING (true);

-- bread_photos 에 대표 사진 플래그 추가
ALTER TABLE bread_photos ADD COLUMN IF NOT EXISTS is_representative BOOLEAN DEFAULT false;

-- bread_mappings: Gemini 리턴값 → 가게 빵 ID 매핑
CREATE TABLE IF NOT EXISTS bread_mappings (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      UUID        REFERENCES stores(id) ON DELETE CASCADE NOT NULL,
  gemini_result TEXT        NOT NULL,
  bread_id      UUID        REFERENCES breads(id) ON DELETE CASCADE NOT NULL,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(store_id, gemini_result)
);

ALTER TABLE bread_mappings ENABLE ROW LEVEL SECURITY;

-- 오너: 전체 관리
CREATE POLICY "owner_manage_mappings" ON bread_mappings FOR ALL USING (
  EXISTS (SELECT 1 FROM stores WHERE id = bread_mappings.store_id AND owner_id = auth.uid())
);
-- 누구나 읽기 (직원/손님 인식 시 사용)
CREATE POLICY "public_read_mappings" ON bread_mappings FOR SELECT USING (true);
-- 비로그인 직원도 매핑 추가 가능 (store_id 알아야 함)
CREATE POLICY "anon_insert_mappings" ON bread_mappings FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM stores WHERE id = bread_mappings.store_id)
);

-- ────────────────────────────────────────────────
-- Storage 버킷 설정 (대시보드에서 수동 생성)
-- ────────────────────────────────────────────────
-- 1. Storage → New bucket → 이름: bread-photos  → Public bucket: ON
-- 2. Storage → New bucket → 이름: bread-models  → Public bucket: ON

-- ────────────────────────────────────────────────
-- Auth 설정 (대시보드에서 확인)
-- ────────────────────────────────────────────────
-- Authentication → Providers → Email → Enabled: ON
-- (테스트 중에는 "Confirm email" 비활성화 권장)
