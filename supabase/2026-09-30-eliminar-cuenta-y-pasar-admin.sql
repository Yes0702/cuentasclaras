-- =====================================================================
-- Cuentas Claras — Eliminar cuenta de la nube y pasar la administración
-- Ejecutar UNA vez en Supabase → SQL Editor. Se puede volver a ejecutar
-- sin problema (create or replace).
-- =====================================================================

-- 1) Pasar la administración del hogar a otro integrante.
--    Solo la puede usar el administrador actual. Él queda como integrante
--    con acceso completo (editar, ver deudas y ver ingresos).
create or replace function public.transferir_administracion(nuevo_admin uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  mi_hogar uuid;
begin
  if auth.uid() is null then
    raise exception 'No hay sesión iniciada';
  end if;

  select hogar_id into mi_hogar from miembros_hogar
    where user_id = auth.uid() and rol = 'admin'
    limit 1;
  if mi_hogar is null then
    raise exception 'Solo el administrador puede pasar la administración';
  end if;
  if nuevo_admin = auth.uid() then
    raise exception 'Ya eres el administrador';
  end if;
  if not exists (select 1 from miembros_hogar where hogar_id = mi_hogar and user_id = nuevo_admin) then
    raise exception 'Esa persona no está en tu hogar';
  end if;

  update miembros_hogar set rol = 'admin'
    where hogar_id = mi_hogar and user_id = nuevo_admin;
  update miembros_hogar
    set rol = 'miembro',
        permisos = coalesce(permisos, '{}'::jsonb) || '{"editar":true,"ver_deudas":true,"ver_ingresos":true}'::jsonb
    where hogar_id = mi_hogar and user_id = auth.uid();
  return true;
end;
$$;

-- 2) Eliminar mi cuenta de la nube (lo exige Google Play).
--    - Integrante: sale del hogar y se borra su cuenta. El hogar y sus datos
--      siguen intactos para los demás.
--    - Administrador con más integrantes: NO se deja — primero debe pasar la
--      administración a otro integrante.
--    - Administrador solo en su hogar: se borran su cuenta y el hogar en la
--      nube (datos, invitaciones).
--    Todo pasa en una sola transacción: si algo falla, no se borra nada.
--    Los datos guardados en el celular NO se tocan (eso lo maneja la app).
create or replace function public.eliminar_mi_cuenta()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  yo uuid := auth.uid();
  h record;
begin
  if yo is null then
    raise exception 'No hay sesión iniciada';
  end if;

  -- Administrador con más gente en su hogar: primero debe pasar la administración.
  if exists (
    select 1 from miembros_hogar a
    where a.user_id = yo and a.rol = 'admin'
      and exists (select 1 from miembros_hogar o where o.hogar_id = a.hogar_id and o.user_id <> yo)
  ) then
    raise exception 'Primero pasa la administración de tu hogar a otro integrante';
  end if;

  -- Hogares donde es el único integrante (o que creó y quedaron sin nadie):
  -- se borra el hogar completo.
  for h in
    select id from hogares x
    where (
      x.id in (select hogar_id from miembros_hogar where user_id = yo)
      or x.creado_por = yo
    )
    and not exists (select 1 from miembros_hogar o where o.hogar_id = x.id and o.user_id <> yo)
  loop
    delete from estado_app where hogar_id = h.id;
    delete from invitaciones where hogar_id = h.id;
    delete from miembros_hogar where hogar_id = h.id;
    delete from hogares where id = h.id;
  end loop;

  -- Sale de los hogares donde era integrante (el hogar sigue para los demás).
  delete from miembros_hogar where user_id = yo;

  -- Hogares que creó pero cuya administración ya pasó a otra persona: quedan
  -- a nombre del administrador actual (o de cualquier integrante que quede).
  update hogares x
    set creado_por = coalesce(
      (select user_id from miembros_hogar a where a.hogar_id = x.id and a.rol = 'admin' limit 1),
      (select user_id from miembros_hogar a where a.hogar_id = x.id limit 1)
    )
    where x.creado_por = yo;

  -- Invitaciones que creó o que usó.
  delete from invitaciones where creado_por = yo or usado_por = yo;

  -- Códigos de acceso que usó: quedan inservibles (nunca vuelven a estar
  -- disponibles para otra persona), solo se quita el enlace a su cuenta.
  update codigos_acceso
    set codigo = codigo || '-eliminado-' || replace(id::text, '-', ''),
        usado_por = null
    where usado_por = yo;

  -- Por último, la cuenta (correo) en sí.
  delete from auth.users where id = yo;
  return true;
end;
$$;

-- Solo usuarios con sesión iniciada pueden llamarlas.
revoke all on function public.transferir_administracion(uuid) from public, anon;
grant execute on function public.transferir_administracion(uuid) to authenticated;
revoke all on function public.eliminar_mi_cuenta() from public, anon;
grant execute on function public.eliminar_mi_cuenta() to authenticated;
