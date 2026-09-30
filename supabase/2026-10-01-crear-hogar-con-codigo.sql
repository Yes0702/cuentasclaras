-- =====================================================================
-- Cuentas Claras — Función que faltaba: crear_hogar_con_codigo
-- Ejecutar UNA vez en Supabase → SQL Editor. Se puede volver a ejecutar
-- sin problema.
--
-- Desde la versión 9.14 la app crea el hogar llamando a esta función, pero
-- nunca quedó creada en Supabase: por eso a las personas nuevas les salía
-- "Could not find the function public.crear_hogar_con_codigo". También la
-- necesita crear_hogar_gratis (modo gratis sin código).
--
-- Hace en UN solo paso lo mismo que la app hacía antes en dos, con las dos
-- funciones que ya tienes:
--   1) canjear_codigo_acceso  → gasta el código y dice el tope de personas
--   2) crear_hogar_propio     → crea el hogar y deja a la persona como admin
-- Si algo falla a mitad de camino, se deshacen los dos y el código NO se
-- pierde (se puede volver a intentar con el mismo código).
-- Devuelve el tope de personas, o null si el código no es válido o ya se usó.
-- =====================================================================

create or replace function public.crear_hogar_con_codigo(codigo_input text, nuevo_hogar_id uuid, nombre_input text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tope integer;
begin
  if auth.uid() is null then
    raise exception 'No hay sesión iniciada';
  end if;

  v_tope := public.canjear_codigo_acceso(trim(codigo_input));
  if v_tope is null then
    return null;   -- código inválido o ya usado: la app lo vuelve a pedir
  end if;

  perform public.crear_hogar_propio(nuevo_hogar_id, v_tope, coalesce(nullif(trim(nombre_input), ''), 'Mi hogar'));
  return v_tope;
end;
$$;

revoke all on function public.crear_hogar_con_codigo(text, uuid, text) from public, anon;
grant execute on function public.crear_hogar_con_codigo(text, uuid, text) to authenticated;
