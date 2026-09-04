-- Enum values must be committed before a later migration can safely use them.
alter type public.challenge_status add value if not exists 'awaiting_reveal' after 'active';
