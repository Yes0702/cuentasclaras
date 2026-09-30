-- =====================================================================
-- Cuentas Claras — Guardado "con candado" de los datos del hogar
-- Ejecutar UNA vez en Supabase → SQL Editor. Se puede volver a ejecutar
-- sin problema.
--
-- Antes, cada celular reemplazaba el hogar completo en la nube al guardar,
-- sin revisar si otro celular lo había cambiado mientras tanto. Ahora la nube
-- solo acepta el guardado si nadie la cambió desde la última vez que ese
-- celular la vio; si alguien sí la cambió, la app trae lo nuevo, une los dos
-- y vuelve a guardar.
-- =====================================================================

-- 1) La fecha de cada guardado la pone el servidor, en milisegundos y siempre
--    mayor que la anterior (así dos guardados nunca quedan con la misma fecha).
create or replace function cc_set_actualizado_en()
returns trigger as $$
begin
  if tg_op = 'UPDATE' and old.actualizado_en is not null then
    new.actualizado_en = greatest(
      date_trunc('milliseconds', clock_timestamp()),
      old.actualizado_en + interval '1 millisecond'
    );
  else
    new.actualizado_en = date_trunc('milliseconds', clock_timestamp());
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists cc_estado_app_actualizado_en on estado_app;
create trigger cc_estado_app_actualizado_en
before insert or update on estado_app
for each row execute function cc_set_actualizado_en();

-- 2) Guardar con candado.
--    p_base = la fecha de la versión de la nube sobre la que el celular hizo sus
--    cambios. Si la nube sigue en esa versión, se guarda; si no, NO se guarda y
--    se devuelve la fecha actual para que la app traiga lo nuevo y una.
--    Solo pueden guardar los integrantes del hogar con permiso de editar.
create or replace function public.guardar_estado_hogar(p_hogar uuid, p_datos jsonb, p_base timestamptz)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_puede boolean;
  v_actual timestamptz;
  v_nuevo timestamptz;
begin
  if auth.uid() is null then
    raise exception 'No hay sesión iniciada';
  end if;

  select (m.rol = 'admin' or coalesce(m.permisos->>'editar', 'true') <> 'false')
    into v_puede
    from miembros_hogar m
    where m.hogar_id = p_hogar and m.user_id = auth.uid();
  if v_puede is null then
    raise exception 'No perteneces a este hogar';
  end if;
  if not v_puede then
    raise exception 'Tu cuenta no tiene permiso para editar';
  end if;

  -- "for update" bloquea la fila: dos celulares guardando al mismo tiempo se
  -- atienden de a uno, y el segundo ve el cambio del primero.
  select e.actualizado_en into v_actual
    from estado_app e
    where e.hogar_id = p_hogar
    for update;

  if not found then
    insert into estado_app (hogar_id, datos) values (p_hogar, p_datos)
      returning actualizado_en into v_nuevo;
    return jsonb_build_object('ok', true, 'actualizado_en', v_nuevo);
  end if;

  if p_base is null or v_actual is distinct from p_base then
    return jsonb_build_object('ok', false, 'actualizado_en', v_actual);
  end if;

  update estado_app set datos = p_datos
    where hogar_id = p_hogar
    returning actualizado_en into v_nuevo;
  return jsonb_build_object('ok', true, 'actualizado_en', v_nuevo);
end;
$$;

revoke all on function public.guardar_estado_hogar(uuid, jsonb, timestamptz) from public, anon;
grant execute on function public.guardar_estado_hogar(uuid, jsonb, timestamptz) to authenticated;

-- 3) Desde ahora los celulares solo pueden ESCRIBIR los datos del hogar a
--    través de guardar_estado_hogar (con candado y revisando el permiso de
--    editar). Leer sigue igual (política "ver estado de mi hogar").
drop policy if exists "guardar estado de mi hogar" on estado_app;
drop policy if exists "ver estado de mi hogar" on estado_app;
create policy "ver estado de mi hogar" on estado_app for select
  using (hogar_id in (select hogar_id from miembros_hogar where user_id = auth.uid()));
