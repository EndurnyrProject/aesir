defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgMoonlit do
  @moduledoc """
  Moonlit Water Mill maintains a wall-free nine-by-nine field in both modes.

  Both modes require an adjacent partner when the cast begins. Performers are
  always rooted and each pays `4 * caster level` SP every ten seconds. Neither
  mode grants fatigue or an occupant status.

  Intruders are pushed two cells along their own facing on entry. Occupants
  already present are swept on the first manager interval, not inside the
  caster's session. Performers are never pushed.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 395,
    name: :cg_moonlit,
    display_name: "Moonlit Water Mill",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 3,
    knockback: 2,
    duration: [20_000, 25_000, 30_000, 35_000, 40_000],
    sp_cost: [30, 40, 50, 60, 70],
    require_weapon: [:musical, :whip],
    damage_kind: :misc

  use Aesir.ZoneServer.Mmo.Skill.Ensemble

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ensemble.Perform
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Field
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Clown.Formulas
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl Active
  @spec begin_attempt(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def begin_attempt(caster, _target, _level, definition) do
    with {:ok, caster} <- Perform.begin_attempt(caster, definition) do
      if Formulas.box_wall_free?(caster.map_name, caster.x, caster.y, 4),
        do: {:ok, caster},
        else: {:error, :blocked_by_wall}
    end
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, term()}
  def cast(caster, :self, level, definition),
    do:
      Perform.perform_field(caster, definition, level,
        root: :always,
        upkeep: 10,
        upkeep_sp: 4 * level
      )

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()}
  def on_touch(%Group{state: %{performance: %{performers: performers}}} = group, {type, id}) do
    with false <- type == :player and id in performers,
         true <- Targeting.placement_reaches?(definition(), {type, id}),
         {:ok, {_module, unit, _pid}} <- UnitRegistry.get_unit(type, id) do
      {dx, dy} = Geometry.facing_delta(unit.dir)
      Knockback.knockback(type, id, unit.x - dx, unit.y - dy, 2)
    end

    {:ok, group}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{state: %{performance: perf}} = group, now) do
    swept =
      if Map.get(perf, :moonlit_swept, false) do
        group
      else
        sweep(group)
        update_in(group.state.performance, &Map.put(&1, :moonlit_swept, true))
      end

    Field.on_interval(swept, now)
  end

  defp sweep(%Group{center: {x, y}} = group) do
    group.map_name
    |> SpatialIndex.get_all_units_in_range(x, y, 8)
    |> Enum.each(fn {type, id} = mover ->
      with {:ok, {ux, uy, map}} when map == group.map_name <-
             SpatialIndex.get_unit_position(type, id),
           true <- {ux, uy} in group.cells do
        on_touch(group, mover)
      end
    end)
  end
end
