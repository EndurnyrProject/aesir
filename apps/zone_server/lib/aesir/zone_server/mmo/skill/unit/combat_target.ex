defmodule Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget do
  @moduledoc """
  The single boundary between generic combat/spatial code and the skill-unit
  subsystem.

  Ground skill-unit cells (Ice Wall, Pneuma, Storm Gust, ...) are indexed in the
  generic `SpatialIndex` as `{:skill_unit, cell_id}` tuples and registered in the
  generic `UnitRegistry`, so they surface anywhere player and mob units do. Every
  question generic code needs to ask about such a target lives here -- "is this id
  a skill unit?", "resolve it to the combat target contract", "where is it?", and
  "should a spatial query treat it as a combat unit?" -- so callers never
  pattern-match `:skill_unit` inline and never meet an `{:skill_unit, _}` tuple
  without a matching clause.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Id, as: SkillUnitId
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @default_combat %{
    def: 0,
    soft_def: 0,
    flee: 0,
    perfect_dodge: 0,
    element: {:neutral, 1},
    race: :formless,
    size: :medium
  }

  @doc "True when `target_id` falls inside the reserved skill-unit id range."
  @spec target?(integer()) :: boolean()
  def target?(target_id), do: SkillUnitId.skill_unit?(target_id)

  @doc """
  True when a `{unit_type, unit_id}` spatial-index reference denotes a normal
  combat unit (player or mob) rather than a ground skill-unit cell.

  `SpatialIndex.get_all_units_in_range/4` returns skill-unit cells interleaved
  with players and mobs; callers that only operate on real units filter through
  this predicate instead of matching `:skill_unit` themselves.
  """
  @spec combat_unit?(Ref.t()) :: boolean()
  def combat_unit?({:skill_unit, _cell_id}), do: false
  def combat_unit?(target_ref), do: Ref.valid?(target_ref)

  @doc """
  True when `target_ref` should be excluded from an offensive selection
  because it is the acting caster's own unit.

  By default a caster never hits itself with its own ground unit or splash;
  a skill that declares `hits_caster: true` (Grand Cross) is the one
  exception -- the caster then stays eligible for its own unit's targets.
  """
  @spec own_caster?({atom(), integer()}, {atom(), integer()}, boolean()) :: boolean()
  def own_caster?(_target_ref, _caster_ref, true), do: false
  def own_caster?(target_ref, caster_ref, false), do: target_ref == caster_ref

  @doc """
  Resolves a skill-unit `target_id` to its owning manager pid and live cell.

  Yields `{:ok, manager_pid, cell, :skill_unit}` (the combat target-state
  contract shared with player and mob lookups) only for a cell the manager
  confirms is currently targetable; a gone or non-targetable cell yields
  `{:error, :target_not_found}`.
  """
  @spec resolve(integer() | {:skill_unit, pos_integer()}) ::
          {:ok, pid(), Cell.t(), :skill_unit} | {:error, :target_not_found}
  def resolve({:skill_unit, target_id}), do: resolve(target_id)

  def resolve(target_id) do
    with {:ok, {_module, _cell, manager_pid}} when is_pid(manager_pid) <-
           UnitRegistry.get_unit(:skill_unit, target_id),
         {:ok, cell} <- SkillUnitManager.targetable_cell(manager_pid, target_id) do
      {:ok, manager_pid, cell, :skill_unit}
    else
      _ -> {:error, :target_not_found}
    end
  end

  @doc """
  Resolves a skill-unit `target_id` to its authoritative `{x, y, map_name}`
  position, gated on the cell still being targetable.
  """
  @spec resolve_position(integer() | {:skill_unit, pos_integer()}) ::
          {:ok, :skill_unit, {integer(), integer(), String.t()}}
          | {:error, :target_not_found}
  def resolve_position({:skill_unit, target_id}), do: resolve_position(target_id)

  def resolve_position(target_id) do
    with {:ok, {_module, _cell, manager_pid}} when is_pid(manager_pid) <-
           UnitRegistry.get_unit(:skill_unit, target_id),
         {:ok, _cell} <- SkillUnitManager.targetable_cell(manager_pid, target_id),
         {:ok, position} <- SpatialIndex.get_unit_position(:skill_unit, target_id) do
      {:ok, :skill_unit, position}
    else
      _ -> {:error, :target_not_found}
    end
  end

  @doc "Builds the lightweight defender used for basic attacks against a cell."
  @spec to_combatant(Cell.t()) :: map()
  def to_combatant(%Cell{} = cell) do
    combat = Map.merge(@default_combat, Map.get(cell.state, :combat, %{}))

    %Combatant{
      unit_id: cell.cell_id,
      unit_type: :skill_unit,
      base_stats: %{str: 0, agi: 0, vit: 0, int: 0, dex: 0, luk: 0},
      combat_stats: %{
        atk: 0,
        def: combat.def,
        hit: 0,
        flee: combat.flee,
        perfect_dodge: combat.perfect_dodge,
        matk: 0,
        mdef: Map.get(combat, :mdef, 0),
        soft_mdef: Map.get(combat, :soft_mdef, 0),
        soft_def: combat.soft_def
      },
      progression: %{base_level: 1, job_level: 1},
      element: combat.element,
      race: combat.race,
      size: combat.size,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 0,
      attack_delay_ms: 0,
      position: {cell.x, cell.y},
      map_name: cell.map_name
    }
    |> Map.put(:hp, cell.hp)
  end
end
