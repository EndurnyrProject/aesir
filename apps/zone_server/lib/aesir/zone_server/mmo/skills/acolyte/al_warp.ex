defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlWarp do
  @moduledoc """
  Warp Portal (AL_WARP). Ground-targeted portal that warps players who step
  onto it to the caster's save point.

  ## Shared behaviour

    - Four levels, SP 35/32/29/26, one Blue Gemstone per portal, range nine,
      single-cell footprint.
    - The portal spends two seconds opening before it accepts anyone, then runs
      out its own lifetime and warps whoever is already standing on the cell at
      the moment it opens. Aesir models the opening as an `opens_at` timestamp:
      touches before it are ignored, and the group's total lifetime is the two
      seconds plus the portal's own duration.
    - A portal closes after `level + 6` warps.
    - A caster keeps at most three live portals; placing a fourth removes the
      earliest-expiring one first.
    - Only players are warped. The caster is warped like anyone else.

  ## Renewal

  No variable cast: a flat one-second fixed cast and a one-second after-cast
  delay. The portal lasts 10/15/20/25 seconds by level.

  ## Pre-renewal

  A flat one-second variable cast, no fixed component and no after-cast delay at
  all, so the caster chains straight into the next action. The portal is shorter
  lived: 5/10/15/20 seconds by level.

  ## Deviations (both modes)

    - Destination: always the caster's save point, captured at placement. The
      source lets the caster pick the save point or one of up to three memorised
      points from a client menu; Aesir has neither memo points nor a warp-list
      message in the wire protocol yet, so the memo destinations are deferred.
    - The source only warps a player whose walk destination is the portal cell;
      Aesir warps on any cell entry, matching its NPC warp triggers.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 27,
    name: :al_warp,
    display_name: "Warp Portal",
    max_level: 4,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    hit_interval: 1_000,
    unit_duration: [
      renewal: [10_000, 15_000, 20_000, 25_000],
      pre_renewal: [5_000, 10_000, 15_000, 20_000]
    ],
    cast_time: [renewal: [], pre_renewal: List.duplicate(1_000, 4)],
    fixed_cast_time: [renewal: List.duplicate(1_000, 4), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 4), pre_renewal: []],
    sp_cost: [35, 32, 29, 26],
    item_cost: [%{id: 717, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @open_delay 2_000
  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level, caster_type: ct, caster_id: cid}) do
    definition = definition()
    {:ok, {_module, %PlayerState{} = caster, _pid}} = UnitRegistry.get_unit(ct, cid)
    now = System.monotonic_time(:millisecond)

    {:ok,
     %{
       cells: [center],
       state: %{
         dest: {caster.save_map, caster.save_x, caster.save_y},
         uses: level + 6,
         opens_at: now + @open_delay
       },
       interval: definition.hit_interval,
       duration: @open_delay + Enum.at(definition.unit_duration, level - 1),
       lifecycle_policy: %LifecyclePolicy{max_instances_per_caster: 3}
     }}
  end

  # Warps players already standing on the portal cell once the opening phase ends.
  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{} = group, now) do
    if now >= group.state.opens_at do
      warp_occupants(group)
    else
      {:ok, group}
    end
  end

  @spec warp_occupants(Group.t()) :: {:ok, Group.t()} | {:expire, Group.t()}
  defp warp_occupants(%Group{center: {cx, cy}, map_name: map_name} = group) do
    updated =
      map_name
      |> SpatialIndex.get_all_units_in_range(cx, cy, 0)
      |> Enum.filter(&match?({:player, _id}, &1))
      |> Enum.reduce(group, fn {:player, player_id}, acc -> consume_warp(acc, player_id) end)

    case updated do
      %Group{state: %{uses: uses}} when uses <= 0 -> {:expire, updated}
      _ -> {:ok, updated}
    end
  end

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(%Group{} = group, {:player, player_id}) do
    if System.monotonic_time(:millisecond) >= group.state.opens_at do
      case consume_warp(group, player_id) do
        %Group{state: %{uses: uses}} when uses <= 0 -> :expire
        updated -> {:ok, updated}
      end
    else
      {:ok, group}
    end
  end

  def on_touch(%Group{} = group, _mover), do: {:ok, group}

  # Delivers the warp through the player's session (the single writer for
  # player state) and spends one use; a vanished session spends nothing.
  @spec consume_warp(Group.t(), integer()) :: Group.t()
  defp consume_warp(
         %Group{state: %{uses: uses, dest: {map, x, y}} = group_state} = group,
         player_id
       )
       when uses > 0 do
    with {:ok, {_module, target_state, pid}} <- UnitRegistry.get_unit(:player, player_id),
         true <- Unit.living?(target_state) do
      PlayerSession.warp(pid, map, x, y)
      %{group | state: %{group_state | uses: uses - 1}}
    else
      _ -> group
    end
  end

  defp consume_warp(%Group{} = group, _player_id), do: group
end
