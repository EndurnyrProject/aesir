defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlWarp do
  @moduledoc """
  Warp Portal (AL_WARP). Ground-targeted portal that warps players who step
  onto it to the caster's save point.

  ## rAthena (`db/re/skill_db.yml` id 27)

    - SP [35, 32, 29, 26], 1 `Blue_Gemstone` (717), 1000ms fixed cast, 1000ms
      after-cast delay, range 9, single-cell footprint.
    - The portal opens as `UNT_WARP_ACTIVE` with a 2s limit and then morphs to
      `UNT_WARP_WAITING` (`skill.cpp` `skill_unit_timer_sub`), restarting its
      timer at `Duration1` (10/15/20/25s) and warping anyone already standing
      on the cell. Aesir mirrors this as an `opens_at` timestamp: touches
      before it are ignored, and the group duration is `2s + Duration1`.
    - `val1 = skill_lv + 6` (`skill_unitsetting`) - the portal closes after
      `level + 6` warps.
    - `ActiveInstance: 3` - a caster keeps at most 3 live portals; placing a
      4th removes the earliest-expiring one first.
    - Only players are warped (`UNT_WARP_WAITING` onplace warps `BL_PC`; mobs
      only with `battle_config.mob_warp`, which is off by default). The caster
      is warped like anyone else.

  ## Deviations

    - Destination: always the caster's save point, captured at placement. In
      rAthena the caster picks save point or a memo point from a client menu
      (`skill_castend_map`); Aesir has neither memo points nor a warp-list
      message in the wire protocol yet, so the memo destinations are deferred.
    - rAthena only warps a player whose walk destination is the portal cell
      (`sd->ud.to_x == unit->x`); Aesir warps on any cell entry, matching its
      NPC warp triggers.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 27,
    name: :al_warp,
    display_name: "Warp Portal",
    max_level: 4,
    target_type: :ground,
    damage_type: :no_damage,
    range: 9,
    hit_interval: 1_000,
    unit_duration: [10_000, 15_000, 20_000, 25_000],
    fixed_cast_time: [1_000, 1_000, 1_000, 1_000],
    after_cast_delay: [1_000, 1_000, 1_000, 1_000],
    sp_cost: [35, 32, 29, 26],
    item_cost: [%{id: 717, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.TargetState
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

  # Warps players already standing on the portal cell once it opens (rAthena
  # applies the unit effect to occupants when the portal morphs to WAITING).
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
         true <- TargetState.living?(target_state) do
      GenServer.cast(pid, {:warp, map, x, y})
      %{group | state: %{group_state | uses: uses - 1}}
    else
      _ -> group
    end
  end

  defp consume_warp(%Group{} = group, _player_id), do: group
end
