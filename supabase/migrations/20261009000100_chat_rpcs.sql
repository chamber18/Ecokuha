-- Atomic chat helpers (SECURITY INVOKER: RLS still applies, caller must be a participant).

-- After sending a message: +1 unread for every participant except the sender.
create function public.increment_unread_counts(p_conversation_id text, p_sender_id uuid)
returns void language sql security invoker set search_path = '' as $$
  update public.conversations c
     set unread_counts = coalesce((
           select jsonb_object_agg(p::text,
                    coalesce((c.unread_counts ->> p::text)::int, 0) + case when p = p_sender_id then 0 else 1 end)
             from unnest(c.participants) p), '{}'::jsonb)
   where c.id = p_conversation_id
$$;

-- Reset the caller's unread counter and mark others' messages as read by the caller.
create function public.mark_conversation_read(p_conversation_id text)
returns void language plpgsql security invoker set search_path = '' as $$
declare uid uuid := (select auth.uid());
begin
  update public.conversations
     set unread_counts = coalesce(unread_counts, '{}'::jsonb) || jsonb_build_object(uid::text, 0)
   where id = p_conversation_id;
  update public.messages
     set read_by = array_append(read_by, uid::text)
   where conversation_id = p_conversation_id
     and sender_id is distinct from uid::text
     and not (uid::text = any(read_by));
end $$;

revoke execute on function public.increment_unread_counts(text, uuid) from public, anon;
revoke execute on function public.mark_conversation_read(text) from public, anon;
grant execute on function public.increment_unread_counts(text, uuid) to authenticated;
grant execute on function public.mark_conversation_read(text) to authenticated;
