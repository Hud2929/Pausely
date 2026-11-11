-- Objects that exist on the live project but in no migration: an earlier payment system set up by
-- hand. Copied from the live schema on 2026-11-11 (python3 scripts/db_apply.py state) so the rig's
-- "live" starting state has the same shape as the real database. Never run on a real project.

create table public.orders (
    id text primary key,
    user_id uuid references auth.users(id) on delete cascade,
    order_number integer,
    status text,
    total integer,
    currency text,
    paid_at timestamptz,
    refunded_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now(),
    raw_data jsonb
);
alter table public.orders enable row level security;
create policy "Service role can manage orders" on public.orders for all using (auth.role() = 'service_role');
create policy "Users can view their own orders" on public.orders for select using (auth.uid() = user_id);

create table public.user_subscriptions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references auth.users(id) on delete cascade,
    order_id text,
    subscription_id text,
    tier text,
    status text,
    payment_source text,
    activated_at timestamptz,
    cancelled_at timestamptz,
    ended_at timestamptz,
    renews_at timestamptz,
    last_payment_at timestamptz,
    payment_failed boolean default false,
    payment_failed_at timestamptz,
    payment_recovered_at timestamptz,
    created_at timestamptz default now(),
    updated_at timestamptz default now()
);
alter table public.user_subscriptions enable row level security;
create policy "Service role can manage subscriptions" on public.user_subscriptions for all using (auth.role() = 'service_role');
create policy "Users can view their own subscription" on public.user_subscriptions for select using (auth.uid() = user_id);

-- A paid subscription marks the account Pro. Runs with the rights of whoever changed the row.
create function public.sync_subscription_to_profile() returns trigger language plpgsql as $$
begin
    update profiles
    set is_pro = (new.status = 'active'),
        pro_tier = case when new.status = 'active' then new.tier else null end,
        updated_at = now()
    where id = new.user_id;
    return new;
end;
$$;
create trigger sync_subscription_trigger after insert or update on public.user_subscriptions
    for each row execute function public.sync_subscription_to_profile();

-- Three views that join the payment rows to the account's email. A view answers with its owner's
-- rights, and by default every API role may read it.
create view public.active_subscriptions as
    select us.*, u.email as user_email, p.display_name as user_display_name
    from public.user_subscriptions us
    join auth.users u on us.user_id = u.id
    left join public.profiles p on p.id = us.user_id
    where us.status = 'active';

create view public.expiring_subscriptions as
    select us.*, u.email as user_email, p.display_name as user_display_name,
           case when us.renews_at is not null then extract(day from us.renews_at - now())::integer end as days_until_renewal
    from public.user_subscriptions us
    join auth.users u on us.user_id = u.id
    left join public.profiles p on p.id = us.user_id
    where us.status = 'active';

create view public.payment_failures as
    select us.*, u.email as user_email, p.display_name as user_display_name,
           extract(day from now() - us.payment_failed_at)::integer as days_since_failure
    from public.user_subscriptions us
    join auth.users u on us.user_id = u.id
    left join public.profiles p on p.id = us.user_id
    where us.payment_failed;
