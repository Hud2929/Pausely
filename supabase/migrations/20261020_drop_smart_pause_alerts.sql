-- The "smart pause" suggestions feature does not exist. Remove its leftover preference column.
-- The app never reads or writes this column. Safe to run more than once.
alter table public.user_settings drop column if exists smart_pause_alerts;
