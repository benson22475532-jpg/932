-- 二技中隊92期2隊 新生報到系統 資料表結構
-- 在 Supabase 專案的 SQL Editor 貼上執行一次即可

create table if not exists students_92_2 (
  id bigserial primary key,
  exam_no text unique not null,
  name text not null,
  dept text not null,
  agency text not null,
  gender text not null,
  birth_roc text not null,           -- 民國格式生日字串，例如 "89/7/31"
  is_recruited boolean not null default false,   -- 甄試生（准考證編號開頭為「甄」自動判斷）
  is_returning boolean not null default false,   -- 復學生（手動勾選）
  is_indigenous boolean not null default false,  -- 原住民（手動勾選）
  checked_in boolean not null default false,     -- 已報到
  checkin_time timestamptz,
  illness_flag boolean not null default false,   -- 重大傷病（有/無）
  illness_note text not null default '',         -- 重大傷病備註（僅供簡短代號/提示，不要輸入詳細病歷）
  cold_flag boolean not null default false,      -- 感冒情形（有/無）
  cold_note text not null default '',            -- 感冒情形備註
  remark text not null default '',               -- 其他備註
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 表已存在時（第二次以後執行）補上新欄位，不會影響既有資料
alter table students_92_2 add column if not exists cold_flag boolean not null default false;
alter table students_92_2 add column if not exists cold_note text not null default '';
alter table students_92_2 add column if not exists remark text not null default '';

create index if not exists idx_students_92_2_exam_no on students_92_2 (exam_no);

-- updated_at 自動更新
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_students_92_2_updated_at on students_92_2;
create trigger trg_students_92_2_updated_at
  before update on students_92_2
  for each row execute function set_updated_at();

-- Row Level Security
-- 這個網站會部署到 GitHub Pages（公開網址，任何人都能打開頁面），
-- 所以資料存取權限一定要綁在「有沒有登入」上，不能只用 anon key 就能讀寫。
-- 只有透過 Supabase Auth 登入成功的工作人員帳號，才能讀寫這張表；
-- 未登入的訪客（anon）呼叫 API 一律被 RLS 擋掉，回傳空結果。
-- 因為報到現場只需要「讀取全部、更新報到相關欄位、新增新生」，沒有需要刪除資料的情境，
-- 所以刻意不開放 delete，降低誤刪風險。
alter table students_92_2 enable row level security;

drop policy if exists "anon can select" on students_92_2;
drop policy if exists "anon can update" on students_92_2;
drop policy if exists "anon can insert" on students_92_2;

drop policy if exists "authenticated can select" on students_92_2;
create policy "authenticated can select"
  on students_92_2 for select
  using (auth.role() = 'authenticated');

drop policy if exists "authenticated can update" on students_92_2;
create policy "authenticated can update"
  on students_92_2 for update
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

drop policy if exists "authenticated can insert" on students_92_2;
create policy "authenticated can insert"
  on students_92_2 for insert
  with check (auth.role() = 'authenticated');

-- 啟用 Realtime（讓多台電腦即時看到彼此的報到狀態）
-- 用 DO block 檢查是否已加入過，這樣這份腳本可以安全重複執行不會報錯
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'students_92_2'
  ) then
    alter publication supabase_realtime add table students_92_2;
  end if;
end $$;

-- 工作人員帳號請到 Supabase 後台 Authentication → Users → Add user 手動建立
-- （email + password），不要用 SQL 建立，避免密碼明碼留在這份檔案或 git 紀錄裡。
