-- Junkshop registration no longer requires documents (business permit / owner ID).
-- Junkshop documents were only stored inside junkshops.junkshop_profile -> 'documents'.
update public.junkshops
   set junkshop_profile = junkshop_profile - 'documents'
 where junkshop_profile ? 'documents';

comment on column public.junkshops.junkshop_profile is
  'jsonb {business:{...}, location:{...}} (no documents)';
