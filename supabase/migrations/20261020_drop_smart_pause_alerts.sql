-- The "smart pause" suggestions feature does not exist. Remove its leftover preference column.
-- The app never reads or writes this column. Safe to run more than once.
-- The table is created by 20261022a, which sorts after this file: on a database built from scratch
-- there is nothing to drop yet, so the step is skipped instead of failing.
do $$
begin
    if to_regclass('public.user_settings') is not null then
        alter table public.user_settings drop column if exists smart_pause_alerts;
    end if;
end $$;
