-- Create rooms table
create table public.rooms (
  id text primary key,
  code text not null unique,
  name text not null,
  host_id uuid references auth.users(id) on delete cascade not null,
  game_mode text not null,
  status text not null,
  created_at timestamptz default now() not null,
  members jsonb not null default '[]'::jsonb,
  messages jsonb not null default '[]'::jsonb
);

-- Enable Row Level Security
alter table public.rooms enable row level security;

-- Create indexes for better performance
create index idx_rooms_host_id on public.rooms(host_id);
create index idx_rooms_status on public.rooms(status);
create index idx_rooms_code on public.rooms(code);

-- Create policy: Allow authenticated users to view all rooms
create policy "Allow read access to all users"
on public.rooms for select
to authenticated
using (true);

-- Create policy: Allow users to create rooms
create policy "Allow insert for authenticated users"
on public.rooms for insert
to authenticated
with check (true);

-- Create policy: Allow room host to update their room
create policy "Allow update for room host"
on public.rooms for update
using (auth.uid() = host_id);

-- Create policy: Allow room host to delete their room
create policy "Allow delete for room host"
on public.rooms for delete
using (auth.uid() = host_id);

-- Create a function to check if a user is a room member
create or replace function is_room_member(room_id text, user_id uuid)
returns boolean as $$
  select exists (
    select 1 
    from public.rooms r
    where r.id = $1 
    and r.members::jsonb @> jsonb_build_array(user_id::text)::jsonb
  );
$$ language sql security definer;

-- Create policy: Allow room members to view room details
create policy "Allow read access to room members"
on public.rooms for select
using (
  is_room_member(id, auth.uid())
);

-- Create policy: Allow room members to update room (for joining/leaving)
create policy "Allow update for room members"
on public.rooms for update
using (
  is_room_member(id, auth.uid())
);

-- Create a function to update the updated_at column
drop trigger if exists on_rooms_updated on public.rooms;
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Add updated_at column if it doesn't exist
do $$
begin
  if not exists (select 1 from information_schema.columns 
                where table_schema = 'public' 
                and table_name = 'rooms' 
                and column_name = 'updated_at') then
    alter table public.rooms add column updated_at timestamptz default now();
  end if;
end
$$;

-- Create the trigger
create trigger on_rooms_updated
before update on public.rooms
for each row
execute function update_updated_at_column();

-- Create a function to notify when a room is updated
create or replace function notify_room_updated()
returns trigger as $$
begin
  perform pg_notify('room_updated', json_build_object('id', new.id)::text);
  return new;
end;
$$ language plpgsql;

-- Create the trigger
create trigger on_room_updated
after update on public.rooms
for each row
execute function notify_room_updated();
