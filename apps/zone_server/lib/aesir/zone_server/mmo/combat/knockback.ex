defmodule Aesir.ZoneServer.Mmo.Combat.Knockback do
  @moduledoc """
  Collision-aware, session-owned combat displacement.

  This module computes a landing cell from the current spatial snapshot. The
  target session validates that snapshot and owns movement commitment and
  publication.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.EquipmentBonuses
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Pathfinding
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @type result :: :ok | {:ok, {integer(), integer()}} | {:error, atom()}

  @type skill_result :: %{
          hit?: boolean(),
          target_survives?: boolean(),
          coma?: boolean()
        }

  @type target_type :: :player | :mob | :homunculus | :skill_unit

  @type skill_options :: [
          base_distance: non_neg_integer(),
          origin: {integer(), integer()} | nil,
          native_enabled: boolean(),
          native_target_types: [target_type()],
          native_requires_survival: boolean(),
          equipment_blow: boolean()
        ]

  @doc """
  Combines a landed named skill's native and equipment knockback distances.

  Native conditions gate only `base_distance`. The final signed sum is floored
  at zero before one collision-aware, target-owned displacement request.
  `equipment_blow: false` drops the equipment distance too, for a skill whose
  hit carries no knockback at all.
  """
  @spec skill(Combatant.t(), Combatant.t(), pos_integer(), skill_result(), skill_options()) ::
          result()
  def skill(attacker, target, skill_id, skill_result, opts \\ []) do
    distance =
      max(
        0,
        native_distance(target, skill_result, opts) +
          equipment_distance(attacker, skill_id, opts)
      )

    request_skill_displacement(skill_result, attacker, target, distance, opts)
  end

  @doc """
  Requests collision-aware movement away from `{from_x, from_y}`.

  `opts[:source_boss?]` marks the push as coming from a boss: a pre-renewal
  Basilica caster resists every other source. `opts[:position]` names the cell
  the unit stands on when the caller already requested an earlier push of it in
  the same synchronous sequence that has not landed yet (the target session
  applies queued pushes in order, each validated against its expected cell).
  """
  @spec knockback(atom(), integer(), integer(), integer(), non_neg_integer(), keyword()) ::
          result()
  def knockback(unit_type, unit_id, from_x, from_y, distance, opts \\ [])

  def knockback(:skill_unit, _unit_id, _from_x, _from_y, _distance, _opts), do: :ok

  def knockback(unit_type, unit_id, from_x, from_y, distance, opts) do
    with {:ok, {x, y, map_name}} <- current_position(unit_type, unit_id, opts),
         {:ok, {module, state, pid}} <- displacement_owner(unit_type, unit_id),
         :ok <- ensure_living(state),
         {:ok, _map} <- MapCache.get(map_name) do
      if blown_immune?({unit_type, unit_id}, map_name, module, state, opts) do
        {:ok, {x, y}}
      else
        {dx, dy} = push_direction({x, y}, {from_x, from_y})
        destination = blow_path(map_name, x, y, dx, dy, distance)
        request_knockback(unit_type, unit_id, pid, {x, y, map_name}, destination)
      end
    end
  end

  @doc """
  Requests collision-aware movement toward `{target_x, target_y}`.

  Without options the pull moves any unit, a boss included (Spider Web's
  catch). `blown_immunity: true` applies the same resistance as a knockback (a siege map, a knockback-immune monster,
  no-knockback gear, a pre-renewal Basilica caster).
  """
  @spec pull_to(atom(), integer(), integer(), integer(), keyword()) :: result()
  def pull_to(unit_type, unit_id, target_x, target_y, opts \\ [])

  def pull_to(:skill_unit, _unit_id, _target_x, _target_y, _opts), do: :ok

  def pull_to(unit_type, unit_id, target_x, target_y, opts) do
    with {:ok, {x, y, map_name}} <- SpatialIndex.get_unit_position(unit_type, unit_id),
         {:ok, {module, state, pid}} <- displacement_owner(unit_type, unit_id),
         :ok <- ensure_living(state),
         {:ok, map_data} <- MapCache.get(map_name) do
      immune? =
        Keyword.get(opts, :blown_immunity, false) and
          blown_immune?({unit_type, unit_id}, map_name, module, state, [])

      if immune? do
        {:ok, {x, y}}
      else
        destination = pull_path(map_data, {x, y}, {target_x, target_y})
        request_displacement(unit_type, unit_id, pid, {x, y, map_name}, destination)
      end
    end
  end

  @doc """
  Requests an authoritative self-relocation without hostile boss immunity.
  """
  @spec relocate(atom(), integer(), integer(), integer()) :: result()
  def relocate(unit_type, unit_id, x, y) do
    with {:ok, {expected_x, expected_y, map_name}} <-
           SpatialIndex.get_unit_position(unit_type, unit_id),
         {:ok, {_module, state, pid}} <- displacement_owner(unit_type, unit_id),
         :ok <- ensure_living(state),
         {:ok, _map} <- MapCache.get(map_name) do
      GenServer.cast(
        pid,
        {:movement, {:relocate, expected_x, expected_y, map_name, x, y}}
      )

      {:ok, {x, y}}
    end
  end

  defp current_position(unit_type, unit_id, opts) do
    with {:ok, {_x, _y, map_name}} = indexed <- SpatialIndex.get_unit_position(unit_type, unit_id) do
      case Keyword.get(opts, :position) do
        {x, y} -> {:ok, {x, y, map_name}}
        nil -> indexed
      end
    end
  end

  defp blown_immune?({unit_type, unit_id}, map_name, module, state, opts) do
    Rules.ground?(map_name) or knockback_immune?(module, state) or
      anchored_by_basilica?(unit_type, unit_id, opts)
  end

  # A player carrying the `:no_knockback` equipment flag or a knockback-immune
  # monster resists being blown away. Unit types without the optional
  # `knockback_immune?/1` callback are never immune. Pull effects are not gated
  # here.
  @spec knockback_immune?(module(), any()) :: boolean()
  defp knockback_immune?(module, state) do
    function_exported?(module, :knockback_immune?, 1) and module.knockback_immune?(state)
  end

  defp anchored_by_basilica?(unit_type, unit_id, opts) do
    not Keyword.get(opts, :source_boss?, false) and
      StatusStorage.has_status?(unit_type, unit_id, :sc_basilica_caster)
  end

  defp displacement_owner(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {module, state, pid}} when is_pid(pid) ->
        if Process.alive?(pid),
          do: {:ok, {module, state, pid}},
          else: {:error, :owner_unavailable}

      _ ->
        {:error, :owner_unavailable}
    end
  end

  defp ensure_living(state), do: if(Unit.living?(state), do: :ok, else: {:error, :target_dead})

  defp equipment_distance(attacker, skill_id, opts) do
    if Keyword.get(opts, :equipment_blow, true),
      do: EquipmentBonuses.add_skill_blow(attacker, skill_id),
      else: 0
  end

  defp native_distance(target, skill_result, opts) do
    if native_distance_enabled?(target, skill_result, opts),
      do: Keyword.get(opts, :base_distance, 0),
      else: 0
  end

  defp native_distance_enabled?(target, skill_result, opts) do
    Keyword.get(opts, :native_enabled, true) and
      target.unit_type in Keyword.get(opts, :native_target_types, [
        :player,
        :mob,
        :homunculus,
        :skill_unit
      ]) and
      (not Keyword.get(opts, :native_requires_survival, false) or
         skill_result.target_survives? or skill_result.coma?)
  end

  defp request_skill_displacement(%{hit?: true}, attacker, target, distance, opts)
       when distance > 0 do
    {from_x, from_y} = displacement_origin(attacker, opts)

    knockback(target.unit_type, target.unit_id, from_x, from_y, distance,
      source_boss?: attacker.class == :boss
    )
  end

  defp request_skill_displacement(_skill_result, _attacker, _target, _distance, _opts), do: :ok

  defp displacement_origin(attacker, opts) do
    case Keyword.get(opts, :origin) do
      nil -> attacker.position
      origin -> origin
    end
  end

  defp request_knockback(_unit_type, _unit_id, _pid, {x, y, _map_name}, {x, y}),
    do: {:ok, {x, y}}

  defp request_knockback(:homunculus, unit_id, pid, {x, y, map_name}, {dst_x, dst_y}) do
    PlayerSession.knockback_homunculus(pid, unit_id, x, y, map_name, dst_x, dst_y)
    {:ok, {dst_x, dst_y}}
  end

  defp request_knockback(_unit_type, _unit_id, pid, {x, y, map_name}, {dst_x, dst_y}) do
    GenServer.cast(pid, {:movement, {:knockback, x, y, map_name, dst_x, dst_y}})
    {:ok, {dst_x, dst_y}}
  end

  defp request_displacement(_unit_type, _unit_id, _pid, {x, y, _map_name}, {x, y}),
    do: {:ok, {x, y}}

  defp request_displacement(
         :homunculus,
         unit_id,
         pid,
         {x, y, map_name},
         {dst_x, dst_y}
       ) do
    PlayerSession.displace_homunculus(pid, unit_id, x, y, map_name, dst_x, dst_y)
    {:ok, {dst_x, dst_y}}
  end

  defp request_displacement(_unit_type, _unit_id, pid, {x, y, map_name}, {dst_x, dst_y}) do
    GenServer.cast(pid, {:movement, {:displace, x, y, map_name, dst_x, dst_y}})
    {:ok, {dst_x, dst_y}}
  end

  # The step away from the source: the eight-sector direction from the target
  # toward the source, reversed. A target on the source's own cell faces east
  # toward it, so it is pushed west.
  defp push_direction({x, y}, {from_x, from_y}) do
    {toward_x, toward_y} = Geometry.sector_step(from_x - x, from_y - y)
    {-toward_x, -toward_y}
  end

  defp blow_path(_map_name, x, y, 0, 0, _distance), do: {x, y}
  defp blow_path(_map_name, x, y, _dx, _dy, 0), do: {x, y}

  defp blow_path(map_name, x, y, dx, dy, distance) do
    Enum.reduce_while(1..min(distance, 25), {x, y}, fn _step, {cx, cy} ->
      next = {cx + dx, cy + dy}

      if Cell.traversable?(map_name, cx + dx, cy + dy) do
        {:cont, next}
      else
        {:halt, {cx, cy}}
      end
    end)
  end

  defp pull_path(_map_data, position, position), do: position

  defp pull_path(map_data, position, target) do
    case Pathfinding.find_path(map_data, position, target) do
      {:ok, [_ | _] = path} -> List.last(path)
      {:error, _reason} -> position
    end
  end
end
