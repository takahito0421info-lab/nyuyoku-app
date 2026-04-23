-- ============================================================
-- 介護チャット Supabase セットアップ SQL
-- Supabase ダッシュボード > SQL Editor に貼り付けて実行してください
-- ============================================================

-- ── 1. profiles テーブル（ユーザー情報） ──
create table public.profiles (
  id           uuid references auth.users on delete cascade primary key,
  display_name text not null,
  created_at   timestamp with time zone default now()
);

-- ── 2. channels テーブル ──
create table public.channels (
  id          uuid default gen_random_uuid() primary key,
  name        text unique not null,
  description text,
  sort_order  int default 0,
  created_at  timestamp with time zone default now()
);

-- ── 3. messages テーブル ──
create table public.messages (
  id         uuid default gen_random_uuid() primary key,
  channel_id uuid references public.channels on delete cascade not null,
  user_id    uuid references public.profiles on delete cascade not null,
  content    text not null,
  created_at timestamp with time zone default now()
);

-- ── 4. Row Level Security 有効化 ──
alter table public.profiles enable row level security;
alter table public.channels  enable row level security;
alter table public.messages  enable row level security;

-- ── 5. RLS ポリシー（profiles） ──
create policy "ログイン済みはプロフィール閲覧可" on public.profiles
  for select using (auth.role() = 'authenticated');

create policy "自分のプロフィールを作成可" on public.profiles
  for insert with check (auth.uid() = id);

create policy "自分のプロフィールを更新可" on public.profiles
  for update using (auth.uid() = id);

-- ── 6. RLS ポリシー（channels） ──
create policy "ログイン済みはチャンネル閲覧可" on public.channels
  for select using (auth.role() = 'authenticated');

-- ── 7. RLS ポリシー（messages） ──
create policy "ログイン済みはメッセージ閲覧可" on public.messages
  for select using (auth.role() = 'authenticated');

create policy "ログイン済みはメッセージ送信可" on public.messages
  for insert with check (auth.role() = 'authenticated' and auth.uid() = user_id);

create policy "自分のメッセージは削除可" on public.messages
  for delete using (auth.uid() = user_id);

-- ── 8. 新規ユーザー登録時に profiles を自動作成するトリガー ──
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── 9. デフォルトチャンネル ──
insert into public.channels (name, description, sort_order) values
  ('申し送り',   '毎日の申し送り事項を共有する場所',           1),
  ('全体連絡',   'スタッフ全員への重要な連絡',                 2),
  ('ケア情報',   '利用者様のケアに関する情報共有',             3),
  ('業務連絡',   'シフト・物品・設備などの業務連絡',           4),
  ('雑談',       '気軽に話せる場所',                           5);

-- ── 10. Realtime 有効化（messages テーブル） ──
-- ダッシュボード > Database > Replication で messages テーブルを有効にしてください
-- （SQL では設定できないため、手動操作が必要です）
