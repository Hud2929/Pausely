-- In-app account deletion (App Store guideline 5.1.1(v), GDPR Art. 17).
-- The app calls rpc('delete_my_account'). It deletes the signed-in user from auth.users, which
-- cascades to profiles, subscriptions, usage, tracked trials, referrals and devices. Anonymous
-- aggregates (cancel_difficulty_ratings) keep their rows with user_id set to NULL.
-- Idempotent: safe to run more than once.

create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = public, auth, pg_temp
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not signed in' using errcode = '28000';
  end if;

  -- Audit trail required to show the deletion was actioned. No email is kept.
  insert into public.deletion_requests (user_id, source, completed_at, notes)
  values (uid, 'in_app', now(), 'Deleted from the app');

  -- Tables created outside these migrations may not cascade from auth.users.
  if to_regclass('public.user_settings') is not null then
    execute 'delete from public.user_settings where user_id = $1' using uid;
  end if;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public;
revoke all on function public.delete_my_account() from anon;
grant execute on function public.delete_my_account() to authenticated;
