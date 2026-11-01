-- Veil: consent-first face identity.
-- Principles enforced here, not just in the app:
--   1. Nobody is findable unless they hold an active, unexpired consent.
--   2. Face templates are never readable by anyone but their owner.
--   3. A search never reveals who matched. It can only create a request
--      that the matched person approves or denies.
--   4. Every search is attributable and rate limited.
--   5. Revoking consent deletes the template, not just hides it.

create extension if not exists vector;

-- Profiles ------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  bio text check (char_length(bio) <= 160),
  public_key text,            -- Ed25519, base64; used to verify consent records
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;

create policy "own profile" on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

-- Face templates + consent --------------------------------------------------
create table public.face_templates (
  user_id uuid primary key references public.profiles on delete cascade,
  embedding vector(192) not null,
  liveness_passed boolean not null,
  consent_payload jsonb not null,   -- {user_id, scope, issued_at, expires_at}
  consent_signature text not null,  -- Ed25519 over canonical payload
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
alter table public.face_templates enable row level security;

create policy "owner reads template" on public.face_templates
  for select using (user_id = auth.uid());
create policy "owner inserts template" on public.face_templates
  for insert with check (user_id = auth.uid());
create policy "owner deletes template" on public.face_templates
  for delete using (user_id = auth.uid());
-- No update policy: changing consent means re-enrolling with a new signature.

create index face_templates_embedding_idx on public.face_templates
  using hnsw (embedding vector_cosine_ops);

-- Match requests ------------------------------------------------------------
create type public.request_status as enum ('pending', 'approved', 'denied', 'blocked');

create table public.match_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles on delete cascade,
  target_id uuid not null references public.profiles on delete cascade,
  note text check (char_length(note) <= 200),
  similarity real not null,
  status public.request_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (requester_id, target_id),
  check (requester_id <> target_id)
);
alter table public.match_requests enable row level security;

-- Only the TARGET can read the raw row (so the requester never learns who
-- matched until approval). Requesters use my_outgoing_requests().
create policy "target reads incoming" on public.match_requests
  for select using (target_id = auth.uid());

create table public.search_log (
  id bigserial primary key,
  searcher_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.search_log enable row level security;
create policy "own search log" on public.search_log
  for select using (searcher_id = auth.uid());

-- Messages ------------------------------------------------------------------
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.match_requests on delete cascade,
  sender_id uuid not null references public.profiles on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
alter table public.messages enable row level security;
create index messages_request_idx on public.messages (request_id, created_at);

create or replace function public.is_chat_member(rid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from match_requests
    where id = rid and status = 'approved'
      and auth.uid() in (requester_id, target_id)
  );
$$;

create policy "members read" on public.messages
  for select using (public.is_chat_member(request_id));
create policy "members send" on public.messages
  for insert with check (sender_id = auth.uid() and public.is_chat_member(request_id));

alter publication supabase_realtime add table public.messages;

-- Profiles visible to the other side only after approval.
-- security definer so the check can see rows the caller's RLS would hide.
create or replace function public.is_approved_peer(pid uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from match_requests m
    where m.status = 'approved'
      and ((m.requester_id = auth.uid() and m.target_id = pid)
        or (m.target_id = auth.uid() and m.requester_id = pid))
  );
$$;

create policy "approved peers read profile" on public.profiles
  for select using (public.is_approved_peer(id));

-- RPCs ----------------------------------------------------------------------

-- Search. Always returns the same shape whether or not anyone matched, so the
-- endpoint cannot be used to probe whether a face is in the system.
create or replace function public.search_face(query vector(192), note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  threshold constant real := 0.80;   -- cosine similarity; tune per model
  daily_limit constant int := 10;
  best record;
begin
  if me is null then raise exception 'not authenticated'; end if;

  -- Searchers must themselves be verified: accountability for every search.
  if not exists (select 1 from face_templates where user_id = me and liveness_passed) then
    raise exception 'enroll your own face before searching';
  end if;

  if (select count(*) from search_log
      where searcher_id = me and created_at > now() - interval '1 day') >= daily_limit then
    raise exception 'daily search limit reached';
  end if;
  insert into search_log (searcher_id) values (me);

  select t.user_id, 1 - (t.embedding <=> query) as sim into best
  from face_templates t
  where t.user_id <> me
    and t.liveness_passed
    and t.expires_at > now()
    and not exists (
      select 1 from match_requests b
      where b.requester_id = me and b.target_id = t.user_id and b.status = 'blocked')
  order by t.embedding <=> query
  limit 1;

  if best.user_id is not null and best.sim >= threshold then
    insert into match_requests (requester_id, target_id, note, similarity)
    values (me, best.user_id, note, best.sim)
    on conflict (requester_id, target_id) do nothing;
  end if;

  return jsonb_build_object(
    'message', 'If someone who consented to be found matches, they will get your request.');
end;
$$;

create or replace function public.respond_to_request(rid uuid, decision public.request_status)
returns void language plpgsql security definer set search_path = public as $$
begin
  if decision not in ('approved', 'denied', 'blocked') then
    raise exception 'invalid decision';
  end if;
  update match_requests set status = decision, responded_at = now()
  where id = rid and target_id = auth.uid();
  if not found then raise exception 'request not found'; end if;
end;
$$;

-- Outgoing requests: the target's identity is hidden until approval.
create or replace function public.my_outgoing_requests()
returns table (id uuid, status public.request_status, created_at timestamptz,
               peer_id uuid, peer_name text)
language sql stable security definer set search_path = public as $$
  select m.id,
         case when m.status = 'blocked' then 'denied'::request_status else m.status end,
         m.created_at,
         case when m.status = 'approved' then m.target_id end,
         case when m.status = 'approved' then p.display_name end
  from match_requests m join profiles p on p.id = m.target_id
  where m.requester_id = auth.uid()
  order by m.created_at desc;
$$;

-- Incoming requests with the requester's name (the requester chose to reveal
-- themselves by searching).
create or replace function public.my_incoming_requests()
returns table (id uuid, status public.request_status, created_at timestamptz,
               note text, similarity real, peer_id uuid, peer_name text)
language sql stable security definer set search_path = public as $$
  select m.id, m.status, m.created_at, m.note, m.similarity,
         m.requester_id, p.display_name
  from match_requests m join profiles p on p.id = m.requester_id
  where m.target_id = auth.uid()
  order by m.created_at desc;
$$;

-- Hard delete of all biometric data and history for the caller.
create or replace function public.erase_my_face_data()
returns void language sql security definer set search_path = public as $$
  delete from face_templates where user_id = auth.uid();
  delete from search_log where searcher_id = auth.uid();
$$;

revoke all on function public.search_face, public.respond_to_request,
  public.my_outgoing_requests, public.my_incoming_requests,
  public.erase_my_face_data from public, anon;
grant execute on function public.search_face, public.respond_to_request,
  public.my_outgoing_requests, public.my_incoming_requests,
  public.erase_my_face_data to authenticated;
