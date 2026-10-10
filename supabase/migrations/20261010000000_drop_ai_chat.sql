-- AI chat feature removed from the app: drop its tables, trigger and function.
drop table if exists public.ai_messages cascade;
drop table if exists public.ai_conversations cascade;
drop function if exists private.sync_ai_message_count() cascade;
