-- =====================================================================
-- Cuentas Claras — Nube gratis: crear un hogar SIN código de acceso
-- Ejecutar UNA vez en Supabase → SQL Editor. Se puede volver a ejecutar
-- sin problema (no borra nada ni cambia lo que ya tengas).
--
-- Mientras "nube_gratis" esté en true, quien crea su hogar en la nube desde
-- la app NO tiene que escribir ningún código: por dentro se le genera uno
-- (queda anotado como "Gratis automático" en codigos_acceso, para que sepas
-- cuántos hogares se han creado así) y se crea el hogar como siempre.
--
-- Para volver a pedir código (por ejemplo, el día que se cobre la nube):
--   update cc_config set valor = 'false' where clave = 'nube_gratis';
-- Para volver a dejarla gratis:
--   update cc_config set valor = 'true' where clave = 'nube_gratis';
-- Para cambiar cuántas personas puede tener un hogar creado gratis:
--   update cc_config set valor = '5' where clave = 'tope_miembros_gratis';
-- =====================================================================

-- 1) Ajustes de la app (solo los lee el servidor; nadie los puede ver ni
--    cambiar desde la app).
create table if not exists cc_config (
  clave text primary key,
  valor jsonb not null,
  nota  text
);
alter table cc_config enable row level security;

insert into cc_config (clave, valor, nota) values
  ('nube_gratis', 'true', 'true = crear hogar sin código · false = la app pide código de acceso'),
  ('tope_miembros_gratis', '5', 'Cuántas personas (contando al administrador) puede tener un hogar creado gratis')
on conflict (clave) do nothing;

-- 2) ¿La nube está en modo gratis?
create or replace function public.nube_gratis()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select (valor #>> '{}')::boolean from cc_config where clave = 'nube_gratis'), false);
$$;

-- 3) Crear el hogar gratis. Usa por dentro la misma función de siempre
--    (crear_hogar_con_codigo) con un código generado en ese momento, así el
--    hogar queda creado exactamente igual que con un código normal.
--    Devuelve null si la nube NO está en modo gratis (la app pide código).
create or replace function public.crear_hogar_gratis(p_hogar_id uuid, p_nombre text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_codigo text;
  v_tope   int;
  v_res    text;
begin
  if auth.uid() is null then
    raise exception 'No hay sesión iniciada';
  end if;
  if not public.nube_gratis() then
    return null;
  end if;
  if exists (select 1 from miembros_hogar where user_id = auth.uid()) then
    raise exception 'Ya perteneces a un hogar';
  end if;

  select (valor #>> '{}')::int into v_tope from cc_config where clave = 'tope_miembros_gratis';
  insert into codigos_acceso (tope_miembros, nota)
    values (coalesce(v_tope, 5), 'Gratis automático')
    returning codigo into v_codigo;

  v_res := public.crear_hogar_con_codigo(v_codigo, p_hogar_id, coalesce(nullif(trim(p_nombre), ''), 'Mi hogar'));
  if v_res is null then
    -- No se pudo crear: el código generado no queda suelto.
    delete from codigos_acceso where codigo = v_codigo;
  end if;
  return v_res;
end;
$$;

revoke all on function public.nube_gratis() from public, anon;
grant execute on function public.nube_gratis() to authenticated;
revoke all on function public.crear_hogar_gratis(uuid, text) from public, anon;
grant execute on function public.crear_hogar_gratis(uuid, text) to authenticated;
