defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnChargeatk do
  @moduledoc """
  Charge Attack (KN_CHARGEATK), a gap-closing weapon strike.

  Cast at an enemy up to 14 cells away along a straight, unobstructed walkable
  line: the Knight charges to the cell adjacent to the target on the approach
  side, strikes for a flat 700% weapon ratio, and knocks the target back two
  cells directly away from the landing cell.

  The self-reposition is staged as a `ForcedMovement` directive the session
  drains after the cast commits (the same machinery Snap uses), so the caster's
  cell is written and broadcast through the single-writer movement path. A
  blocked line or an unwalkable landing cell fails the cast before any resource
  is spent, leaving the caster in place.

  This module ships without a skill-tree entry or grant mechanism: it is a
  quest skill wired up separately.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1001,
    name: :kn_chargeatk,
    display_name: "Charge Attack",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 14,
    knockback: 2,
    sp_cost: [40],
    quest_skill: true,
    quest_owner_job: :knight

  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%PlayerState{} = caster, {:unit, target_id}, _level, definition) do
    with {:ok, _plan} <- prepare(caster, target_id, definition) do
      :ok
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{} = caster, {:unit, target_id}, level, definition) do
    with {:ok, %{directive: directive, dest: destination}} <-
           prepare(caster, target_id, definition),
         :ok <- strike(caster, target_id, level, definition, destination) do
      {:ok, PlayerState.put_pending_forced_movement(caster, directive)}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  # Resolves the target, computes the landing cell adjacent to it on the caster's
  # side, and validates both the landing cell (walkable, in range) and a straight
  # walkable line for the charge. A blocked line or unwalkable landing fails here,
  # before the interpreter commits any resource.
  @spec prepare(PlayerState.t(), integer(), Definition.t()) ::
          {:ok,
           %{
             directive: ForcedMovement.t(),
             dest: {integer(), integer()}
           }}
          | {:error, atom()}
  defp prepare(%PlayerState{map_name: map} = caster, target_id, definition) do
    unit_type = target_unit_type(target_id)

    with {:ok, {tx, ty, target_map}} <- resolve_position(unit_type, target_id),
         :ok <- ensure_same_map(map, target_map),
         {dest_x, dest_y} = landing_cell(caster, tx, ty),
         {:ok, directive} <- ForcedMovement.validate(caster, dest_x, dest_y, definition.range),
         :ok <- ensure_walkable_line(caster, tx, ty) do
      {:ok, %{directive: directive, dest: {dest_x, dest_y}}}
    end
  end

  @spec strike(
          PlayerState.t(),
          integer(),
          pos_integer(),
          Definition.t(),
          {integer(), integer()}
        ) :: :ok | {:error, atom()}
  defp strike(caster, target_id, level, definition, origin) do
    Combat.execute_skill_attack(caster, target_id,
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 700,
      skip_crit: true,
      skip_range: true,
      base_distance: definition.knockback,
      origin: origin,
      native_target_types: [:player, :mob]
    )
  end

  @spec resolve_position(:mob | :player, integer()) ::
          {:ok, {integer(), integer(), String.t()}} | {:error, :invalid_target}
  defp resolve_position(unit_type, target_id) do
    case SpatialIndex.get_unit_position(unit_type, target_id) do
      {:ok, {x, y, map_name}} -> {:ok, {x, y, map_name}}
      {:error, _reason} -> {:error, :invalid_target}
    end
  end

  @spec ensure_same_map(String.t(), String.t()) :: :ok | {:error, :different_map}
  defp ensure_same_map(map, map), do: :ok
  defp ensure_same_map(_caster_map, _target_map), do: {:error, :different_map}

  @spec ensure_walkable_line(PlayerState.t(), integer(), integer()) ::
          :ok | {:error, :path_blocked}
  defp ensure_walkable_line(%PlayerState{map_name: map, x: cx, y: cy}, tx, ty) do
    if LineOfSight.walkable?(map, {cx, cy}, {tx, ty}),
      do: :ok,
      else: {:error, :path_blocked}
  end

  # The cell adjacent to the target, one step back toward the caster.
  @spec landing_cell(PlayerState.t(), integer(), integer()) :: {integer(), integer()}
  defp landing_cell(%PlayerState{x: cx, y: cy}, tx, ty) do
    {tx + step(cx - tx), ty + step(cy - ty)}
  end

  @spec step(integer()) :: -1 | 0 | 1
  defp step(delta) when delta > 0, do: 1
  defp step(delta) when delta < 0, do: -1
  defp step(_delta), do: 0

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
