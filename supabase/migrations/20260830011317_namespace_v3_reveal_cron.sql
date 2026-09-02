-- Keep the V3 reveal worker isolated from any legacy private helpers and make
-- the scheduled command deterministic on both fresh and upgraded projects.

do $$
begin
  if to_regprocedure('private.mark_due_mosaics_revealed()') is not null
     and to_regprocedure('private.v3_mark_due_mosaics_revealed()') is null
  then
    alter function private.mark_due_mosaics_revealed()
      rename to v3_mark_due_mosaics_revealed;
  end if;
end;
$$;

revoke all on function private.v3_mark_due_mosaics_revealed()
  from public, anon, authenticated;

select cron.unschedule(jobid)
from cron.job
where jobname = 'mosaic-v3-fixed-reveal';

select cron.schedule(
  'mosaic-v3-fixed-reveal',
  '* * * * *',
  $$select private.v3_mark_due_mosaics_revealed();$$
);
