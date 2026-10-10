-- Rebrand: the system sender "BBP Assistant" / 'bbp_assistant' is now
-- "EcoKuha Assistant" / 'ecokuha_assistant' (trigger functions + existing rows).
do $$
declare r record; def text;
begin
  for r in select p.oid from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('public','private') and p.prokind = 'f' and pg_get_functiondef(p.oid) ilike '%bbp%'
  loop
    def := pg_get_functiondef(r.oid);
    def := replace(def, 'bbp_assistant', 'ecokuha_assistant');
    def := replace(def, 'BBP Assistant', 'EcoKuha Assistant');
    execute def;
  end loop;
  update public.messages set sender_id = 'ecokuha_assistant' where sender_id = 'bbp_assistant';
  update public.messages set sender_name = 'EcoKuha Assistant' where sender_name = 'BBP Assistant';
  update public.conversations set last_message_sender_id = 'ecokuha_assistant' where last_message_sender_id = 'bbp_assistant';
  update public.conversations set last_message_sender_name = 'EcoKuha Assistant' where last_message_sender_name = 'BBP Assistant';
end $$;
