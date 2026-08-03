defmodule Aesir.ZoneServer.Mmo.Combat.SplashTargets do
  @moduledoc """
  Selects the valid offensive targets for a center+radius splash/footprint.

  Shared by the splash attack paths and ground skill-unit behaviours (e.g.
  Storm Gust) so the target filter — including the dead-mob guard — lives in
  one place.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Returns the `{unit_type, unit_id}` units that are in the Chebyshev square of
  `radius` cells around `{cx, cy}`, are living enemies of the caster, and are
  alive.

  The spatial index filters by Manhattan distance (a diamond); we query a Manhattan
  radius of `2 * radius` so the full Chebyshev square is covered, then post-filter.

  `hits_caster` (default `false`) is the Grand Cross exception: when `true`
  the caster is not excluded from its own selection on the caster-identity
  check alone.
  """
  @spec select(
          String.t(),
          {integer(), integer()},
          non_neg_integer(),
          integer() | map(),
          boolean()
        ) :: [Ref.t()]
  def select(map_name, {cx, cy}, radius, caster, hits_caster \\ false) do
    caster = resolve_splash_caster(caster)
    caster_ref = {caster.unit_type, caster.unit_id}

    map_name
    |> SpatialIndex.get_all_units_in_range(cx, cy, radius * 2)
    |> Enum.filter(fn target_ref ->
      CombatTarget.combat_unit?(target_ref) and
        not CombatTarget.own_caster?(target_ref, caster_ref, hits_caster) and
        offensive_target_in_square?(caster, target_ref, caster_ref, cx, cy, radius)
    end)
  end

  defp offensive_target_in_square?(
         caster,
         {unit_type, target_id} = target_ref,
         caster_ref,
         cx,
         cy,
         radius
       ) do
    case TargetResolver.resolve(unit_type, target_id) do
      {:ok, _pid, target_state, _target_type} ->
        target = target_state.__struct__.to_combatant(target_state)

        Unit.living?(target_state) and
          splash_hittable?(caster, target, target_ref, caster_ref) and
          splash_hit?(target_state, cx, cy, radius)

      _ ->
        false
    end
  end

  # Hits its own caster only reaches here when the skill allowed it (Grand
  # Cross), past the identity exclusion above; the general enemy check would
  # otherwise reject the caster as its own target.
  defp splash_hittable?(_caster, _target, target_ref, target_ref), do: true

  defp splash_hittable?(caster, target, _target_ref, _caster_ref),
    do: splash_enemy?(caster, target)

  defp resolve_splash_caster(%{unit_type: _unit_type} = caster), do: caster

  defp resolve_splash_caster(caster_id) do
    case UnitRegistry.get_unit(:player, caster_id) do
      {:ok, {module, state, _pid}} -> module.to_combatant(state)
      _ -> %{unit_type: :player, unit_id: caster_id, relation_unavailable: true}
    end
  end

  # If the caster's relation snapshot is unavailable, retain the old safe PvE
  # fallback: mobs remain targetable, but players are not.
  defp splash_enemy?(%{relation_unavailable: true}, %{unit_type: :player}), do: false
  defp splash_enemy?(caster, target), do: Targeting.validate_enemy(caster, target) == :ok

  defp splash_hit?(%{x: tx, y: ty}, x, y, radius),
    do: Geometry.chebyshev_distance(x, y, tx, ty) <= radius
end
