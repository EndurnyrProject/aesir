defmodule Aesir.ZoneServer.Mmo.Combat.SplashTargets do
  @moduledoc """
  Selects the valid offensive targets for a center+radius splash/footprint.

  Shared by the splash attack paths and ground skill-unit behaviours (e.g.
  Storm Gust) so the target filter — including the dead-mob guard — lives in
  one place.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell, as: SkillUnitCell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapCombatTarget
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
  check alone. `target_skill_units: true` additionally admits only live,
  targetable trap cells; all skill units remain excluded by default.
  """
  @spec select(
          String.t(),
          {integer(), integer()},
          non_neg_integer(),
          integer() | map(),
          boolean(),
          keyword()
        ) :: [Ref.t()]
  def select(map_name, center, radius, caster, hits_caster \\ false, opts \\ [])

  def select(map_name, {cx, cy}, radius, caster, hits_caster, opts) do
    caster = resolve_splash_caster(caster)
    caster_ref = {caster.unit_type, caster.unit_id}

    map_name
    |> SpatialIndex.get_all_units_in_range(cx, cy, radius * 2)
    |> Enum.filter(fn target_ref ->
      selectable_target?(target_ref, opts) and
        not CombatTarget.own_caster?(target_ref, caster_ref, hits_caster) and
        offensive_target_in_square?(caster, target_ref, caster_ref, cx, cy, radius, opts)
    end)
  end

  defp selectable_target?(target_ref, opts) do
    CombatTarget.combat_unit?(target_ref) or
      (Keyword.get(opts, :target_skill_units, false) and TrapCombatTarget.targetable?(target_ref))
  end

  defp offensive_target_in_square?(
         caster,
         {unit_type, target_id} = target_ref,
         caster_ref,
         cx,
         cy,
         radius,
         opts
       ) do
    with {:ok, _pid, target_state, _target_type} <-
           TargetResolver.resolve(unit_type, target_id),
         {:ok, target} <- splash_target_combatant(target_state, opts) do
      target_living?(target_ref, target_state) and
        splash_hittable?(caster, target, target_ref, caster_ref) and
        splash_hit?(target_state, cx, cy, radius) and
        splash_visible?(caster.map_name, {cx, cy}, target.position, opts)
    else
      _unavailable -> false
    end
  end

  defp splash_target_combatant(%SkillUnitCell{} = cell, opts) do
    if Keyword.get(opts, :target_skill_units, false),
      do: TrapCombatTarget.to_combatant(cell),
      else: {:ok, CombatTarget.to_combatant(cell)}
  end

  defp splash_target_combatant(target_state, _opts),
    do: {:ok, target_state.__struct__.to_combatant(target_state)}

  defp splash_visible?(map_name, center, target, opts) do
    not Keyword.get(opts, :shoot_range_los, false) or
      LineOfSight.clear?(map_name, center, target)
  end

  defp target_living?({:skill_unit, _cell_id}, _target_state), do: true
  defp target_living?(_target_ref, target_state), do: Unit.living?(target_state)

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
