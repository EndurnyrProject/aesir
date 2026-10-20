defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnChargeatk do
  @moduledoc """
  Charge Attack (KN_CHARGEATK), a gap-closing weapon strike.

  Cast at an enemy up to 14 cells away along a straight line the reference's cell-wall
  test passes: only a cell that is neither walkable nor shootable blocks it, so cliffs and
  water do not. The Knight charges to the cell adjacent to the target on the approach side,
  strikes for a flat 700% weapon ratio, and knocks the target back two cells directly away
  from the landing cell.

  The self-reposition is staged as a `ForcedMovement` directive the session drains after the
  cast commits (the same machinery Snap uses), so the caster's cell is written and broadcast
  through the single-writer movement path. It needs a walkable landing cell and a walkable
  line; when either is refused the Knight stays where they are and still strikes. A blocked
  cell-wall line fails the cast after the requirement is paid, with no cooldown or act delay.

  This module ships without a skill-tree entry or grant mechanism: it is a
  quest skill wired up separately.

  Renewal: 700% weapon damage, 2 cells of knockback, and a 0.5 s cooldown. Pre-renewal: 100% plus 100% per three cells charged (capped at 500%), the target is pushed the charged distance, and the skill has a 0.5 s variable cast instead of a cooldown.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1001,
    name: :kn_chargeatk,
    display_name: "Charge Attack",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 14,
    knockback: [renewal: 2, pre_renewal: 0],
    sp_cost: [40],
    cast_time: [renewal: [], pre_renewal: [500]],
    cooldown: [renewal: [500], pre_renewal: []],
    quest_skill: true,
    quest_owner_job: :knight

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @renewal_ratio 700

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%PlayerState{} = caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _position} <- resolve_target_position(caster, target_id) do
      :ok
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%PlayerState{} = caster, {:unit, target_id}, level, definition) do
    with {:ok, {tx, ty, _target_map}} <- resolve_target_position(caster, target_id),
         :ok <- ensure_clear_line(caster, tx, ty),
         {dest_x, dest_y} = landing_cell(caster, tx, ty),
         :ok <-
           strike(
             caster,
             target_id,
             level,
             definition,
             {dest_x, dest_y},
             charge_distance(caster.x - tx, caster.y - ty)
           ) do
      {:ok, stage_movement(caster, dest_x, dest_y, definition)}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @spec resolve_target_position(PlayerState.t(), integer()) ::
          {:ok, {integer(), integer(), String.t()}}
          | {:error, :invalid_target | :different_map}
  defp resolve_target_position(%PlayerState{map_name: map} = _caster, target_id) do
    with {:ok, {tx, ty, target_map}} <- resolve_position(target_unit_type(target_id), target_id),
         :ok <- ensure_same_map(map, target_map) do
      {:ok, {tx, ty, target_map}}
    end
  end

  @spec strike(
          PlayerState.t(),
          integer(),
          pos_integer(),
          Definition.t(),
          {integer(), integer()},
          non_neg_integer()
        ) :: :ok | {:error, atom()}
  defp strike(caster, target_id, level, definition, origin, distance) do
    {ratio, push} =
      case GameMode.mode() do
        :renewal -> {@renewal_ratio, definition.knockback}
        :pre_renewal -> {classic_ratio(distance), distance}
      end

    Combat.execute_skill_attack(caster, target_id,
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: ratio,
      skip_crit: true,
      skip_range: true,
      base_distance: push,
      origin: origin,
      native_target_types: [:player, :mob]
    )
  end

  # The classic formulas measure the straight-line distance, truncated.
  @doc false
  def charge_distance(dx, dy), do: trunc(:math.sqrt(dx * dx + dy * dy))

  @doc """
  The classic weapon ratio grows with the distance charged: 100 percent plus
  100 for every three cells beyond the first, capped at 500.
  """
  @spec classic_ratio(non_neg_integer()) :: pos_integer()
  def classic_ratio(distance) do
    steps = min(div(max(distance - 1, 0), 3), 4)
    100 + 100 * steps
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

  @spec ensure_clear_line(PlayerState.t(), integer(), integer()) ::
          :ok | {:error, :path_blocked}
  defp ensure_clear_line(%PlayerState{map_name: map, x: cx, y: cy}, tx, ty) do
    if LineOfSight.clear?(map, {cx, cy}, {tx, ty}),
      do: :ok,
      else: {:error, :path_blocked}
  end

  # The reference moves the caster only when the destination is passable and a
  # walkable path reaches it; otherwise the strike still lands from where the
  # caster stands.
  # NOTE: `unit_movepos` searches for any reachable route; this stages the move
  # only when the straight line is walkable, so a landing cell reachable by a
  # detour alone leaves the Knight in place.
  # NOTE: `skill_check_unit_movepos(5, ...)` also blocks the move on battleground
  # and gvg2 maps and under SC_SV_ROOTTWIST; none of the three is modelled here.
  @spec stage_movement(PlayerState.t(), integer(), integer(), Definition.t()) :: PlayerState.t()
  defp stage_movement(%PlayerState{} = caster, dest_x, dest_y, definition) do
    with {:ok, directive} <- ForcedMovement.validate(caster, dest_x, dest_y, definition.range),
         true <- LineOfSight.walkable?(caster.map_name, {caster.x, caster.y}, {dest_x, dest_y}) do
      PlayerState.put_pending_forced_movement(caster, directive)
    else
      _refused -> caster
    end
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
