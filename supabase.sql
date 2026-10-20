-- Run this in Supabase: SQL Editor > New query > paste > Run
-- Safe to run more than once (it will not error if things already exist).

create table if not exists players (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  score int not null default 0,
  color text not null default '#ffc83d',
  photo text,
  created_at timestamptz not null default now()
);
alter table players add column if not exists color text not null default '#ffc83d';
alter table players add column if not exists photo text;

create table if not exists game_state (
  id int primary key default 1 check (id = 1),
  round int not null default 0,
  status text not null default 'closed'
);
insert into game_state (id) values (1) on conflict do nothing;

create table if not exists buzzes (
  id bigint generated always as identity primary key,
  round int not null,
  player_id uuid not null references players(id) on delete cascade,
  created_at timestamptz not null default clock_timestamp(),
  unique (round, player_id)
);

create or replace function buzz(p_player uuid) returns void
language sql security definer as $$
  insert into buzzes (round, player_id)
  select round, p_player from game_state where id = 1 and status = 'open'
  on conflict do nothing;
$$;

alter table players enable row level security;
alter table game_state enable row level security;
alter table buzzes enable row level security;

drop policy if exists "players all" on players;
drop policy if exists "state read" on game_state;
drop policy if exists "state update" on game_state;
drop policy if exists "state insert" on game_state;
drop policy if exists "buzzes read" on buzzes;
create policy "players all" on players for all using (true) with check (true);
create policy "state read" on game_state for select using (true);
create policy "state update" on game_state for update using (true) with check (true);
create policy "state insert" on game_state for insert with check (true);
create policy "buzzes read" on buzzes for select using (true);

grant usage on schema public to anon;
grant select, insert, update, delete on players to anon;
grant select, insert, update on game_state to anon;
grant select on buzzes to anon;
grant execute on function buzz(uuid) to anon;

do $$ begin
  begin alter publication supabase_realtime add table players; exception when others then null; end;
  begin alter publication supabase_realtime add table game_state; exception when others then null; end;
  begin alter publication supabase_realtime add table buzzes; exception when others then null; end;
end $$;
