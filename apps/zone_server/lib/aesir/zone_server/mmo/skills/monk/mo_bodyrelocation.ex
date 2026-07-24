defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBodyrelocation do
  @moduledoc """
  Snap (MO_BODYRELOCATION), a prevalidated same-map relocation.

  The player cast stages a `ForcedMovement` directive the session drains after
  commitment. The mob cast (`mob_cast/5`, an imported `MO_BODYRELOCATION` row)
  has no session to drain a directive, so it commits the relocation through the
  mob's own authoritative single-writer path instead - see `mob_cast/5`.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 264,
    name: :mo_bodyrelocation,
    display_name: "Snap",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 18,
    sp_cost: [14],
    sphere_cost: [1]

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.ForcedMovement
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @adjacent_offsets [{-1, -1}, {-1, 0}, {-1, 1}, {0, -1}, {0, 1}, {1, -1}, {1, 0}, {1, 1}]

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(caster, {:ground, x, y}, _level, _definition) do
    case ForcedMovement.validate(caster, x, y, Formulas.snap_range()) do
      {:ok, _directive} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @impl Active
  @spec dynamic_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(%{character_id: character_id}, _target, _level, _definition) do
    %Cost{
      sp: Formulas.snap_sp_cost(),
      spheres: Formulas.snap_sphere_cost(fury_active?(character_id))
    }
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(caster, {:ground, x, y}, _level, _definition) do
    with {:ok, directive} <- ForcedMovement.validate(caster, x, y, Formulas.snap_range()) do
      {:ok, PlayerState.put_pending_forced_movement(caster, directive)}
    end
  end

  def cast(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  @doc """
  Mob caster path for Snap: an imported `MO_BODYRELOCATION` row (all 67 carry
  `target: target`) relocates the caster next to its player target, closing to
  melee range - the mob analogue of the player relocating toward a ground cell.

  There is no mob session to drain a staged directive, so the move commits
  through the mob's own authoritative relocation envelope: the same
  `{:movement, {:knocked_back, x, y}}` single-writer reposition knockback uses,
  dispatched to the owning `MobSession` so it (not this call) writes the new
  cell and re-syncs the spatial index. The destination follows the player rules -
  same map, walkable, within Snap range - and an unresolved target or invalid
  destination is a clean no-op.
  """
  @impl Active
  @spec mob_cast(MobState.t(), tuple(), pos_integer(), Definition.t(), map()) :: :ok
  def mob_cast(%MobState{} = caster, {:unit, unit_type, target_id}, _level, _definition, _row) do
    with {:ok, {tx, ty, map_name}} <- SpatialIndex.get_unit_position(unit_type, target_id),
         true <- map_name == caster.map_name,
         {:ok, {dest_x, dest_y}} <- relocation_cell(caster, tx, ty),
         {:ok, _directive} <-
           ForcedMovement.validate(caster, dest_x, dest_y, Formulas.snap_range()) do
      relocate(caster.instance_id, dest_x, dest_y)
    end

    :ok
  end

  def mob_cast(%MobState{}, _target, _level, _definition, _row), do: :ok

  # The walkable cell adjacent to the target nearest the caster.
  defp relocation_cell(%MobState{x: mx, y: my, map_name: map}, tx, ty) do
    @adjacent_offsets
    |> Enum.map(fn {dx, dy} -> {tx + dx, ty + dy} end)
    |> Enum.filter(fn {cx, cy} -> Cell.traversable?(map, cx, cy) end)
    |> Enum.min_by(fn {cx, cy} -> Geometry.chebyshev_distance(mx, my, cx, cy) end, fn -> nil end)
    |> case do
      nil -> :error
      cell -> {:ok, cell}
    end
  end

  # Dispatches the reposition to the owning MobSession, the single writer for its
  # position (mirrors `Combat.Knockback.move_unit/5`); a despawned mob is a no-op.
  defp relocate(mob_id, x, y) do
    case UnitRegistry.get_unit(:mob, mob_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        GenServer.cast(pid, {:movement, {:knocked_back, x, y}})

      _ ->
        :ok
    end
  end

  defp fury_active?(character_id) do
    case StatusStorage.get_status(:player, character_id, :sc_explosionspirits) do
      %{expires_at: nil} -> true
      %{expires_at: expires_at} when is_integer(expires_at) -> expires_at > monotonic_now()
      _status -> false
    end
  end

  defp monotonic_now, do: System.monotonic_time(:millisecond)
end
