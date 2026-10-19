defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlWarp do
  @moduledoc """
  Warp Portal offers the caster's save point and, at cast levels two through
  four, up to three memo maps. The cast spends SP and commits its pacing; the
  accepted destination spends the gemstone and places the portal at the chosen
  ground cell. Cancel does not refund the first cast.

  The portal opens after two seconds and visits its occupants once. Later
  entries require a player's walk destination to be the portal cell. Chat-room
  occupants and corpses cannot enter. Each qualifying entry spends one of
  `level + 6` uses before checking destination access. An exact same-map,
  same-cell destination puts the whole portal into its working state, preventing
  further player entries. A caster may hold three live portals.

  Renewal uses a one-second fixed cast and one-second act delay, with total
  lifetimes of 10/15/20/25 seconds. Pre-renewal uses a one-second variable cast,
  no act delay, and total lifetimes of 5/10/15/20 seconds. Both lifetimes include
  the opening phase, and selection places at the caster's current effective
  skill level (or the level of the outstanding item-granted cast).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 27,
    name: :al_warp,
    active_instance: 3,
    no_reiteration: true,
    no_footset: true,
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

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Menu
  alias Aesir.ZoneServer.Mmo.Skill.PortalAccess
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit, as: SkillUnit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active
  @behaviour Ground
  @behaviour Menu
  @open_delay 2_000

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster(), :no_consume}
  def cast(caster, target, level, definition),
    do: cast_with_origin(caster, target, level, definition, :normal)

  @impl Active
  @spec cast_with_origin(
          Active.caster(),
          Active.target(),
          pos_integer(),
          Definition.t(),
          Active.cast_origin()
        ) :: {:ok, Active.caster(), :no_consume}
  def cast_with_origin(%PlayerState{} = caster, {:ground, x, y}, level, _definition, origin) do
    maps = caster |> destinations() |> Enum.take(level) |> Enum.map(& &1["map"])
    maps = Enum.reject(maps, &(&1 in [nil, ""]))

    offer = %{
      skill_id: 27,
      kind: :OPTIONS,
      entry_ids: Enum.map(Enum.with_index(maps), &elem(&1, 1)),
      labels: maps,
      level: level,
      context: %{maps: maps, cell: {x, y}, origin: origin, consume_items?: origin != :item}
    }

    {:ok, %{caster | pending_menu_offer: offer}, :no_consume}
  end

  def cast_with_origin(caster, _target, _level, _definition, _origin),
    do: {:ok, caster, :no_consume}

  @impl Menu
  @spec on_menu_reply(PlayerState.t(), Menu.selection(), pos_integer()) :: Menu.result()
  def on_menu_reply(_caster, _selection, _level), do: {:error, :invalid_target}

  @impl Menu
  @spec on_menu_reply(PlayerState.t(), Menu.selection(), pos_integer(), Menu.context()) ::
          Menu.result()
  def on_menu_reply(caster, selection, cast_level, %{menu: %{context: context}}) do
    caster = on_menu_cancel(caster)

    level =
      min(if(context.origin == :item, do: cast_level, else: Player.skill_level(caster, 27)), 4)

    map = Enum.at(context.maps, selection.id)

    cond do
      not Unit.living?(caster) or
          not StatusInterpreter.can_use_skill?(:player, caster.character_id) ->
        {:silent, caster}

      MapCache.get(map) == {:error, :not_found} ->
        {:failed, caster, :skill_failed}

      length(Storage.get_groups_by_skill_and_caster(:al_warp, :player, caster.character_id)) >= 3 ->
        {:failed, caster, :skill_failed}

      level <= 0 ->
        {:pending, caster}

      true ->
        select_destination(caster, context, level, map)
    end
  end

  defp select_destination(caster, context, level, map) do
    case Enum.find(Enum.take(destinations(caster), level), &(&1["map"] == map)) do
      nil -> {:silent, caster}
      destination -> place_destination(caster, context, level, map, destination)
    end
  end

  defp place_destination(caster, context, level, map, destination) do
    case consume_items(caster, context, level) do
      {:ok, paid} ->
        case SkillUnit.place(paid, :al_warp, level, context.cell,
               state: %{dest: {map, destination["x"], destination["y"]}}
             ) do
          {:ok, _group} -> {:ok, paid}
          {:error, _reason} -> {:silent, paid}
        end

      {:error, reason} ->
        {:failed, caster, reason}
    end
  end

  @impl Menu
  @spec on_menu_cancel(PlayerState.t()) :: PlayerState.t()
  def on_menu_cancel(caster) do
    caster = PlayerState.clear_combat_intent(caster)
    action = if caster.action_state == :attacking, do: :idle, else: caster.action_state
    %{caster | target_id: nil, action_state: action}
  end

  defp destinations(caster),
    do: [
      %{"map" => caster.save_map, "x" => caster.save_x, "y" => caster.save_y} | caster.memo_points
    ]

  defp consume_items(caster, %{consume_items?: false}, _level), do: {:ok, caster}

  defp consume_items(caster, context, level),
    do:
      Player.consume_menu_items(
        caster,
        __MODULE__,
        ground_target(context.cell),
        definition(),
        level
      )

  defp ground_target({x, y}), do: {:ground, x, y}

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level, state: %{dest: dest}}) do
    duration = Enum.at(definition().unit_duration, level - 1)

    {:ok,
     %{
       cells: [center],
       state: %{
         dest: dest,
         uses: level + 6,
         portal: true,
         opened: false,
         working: false,
         opens_at: System.monotonic_time(:millisecond) + @open_delay
       },
       initial_delay: @open_delay,
       interval: duration,
       duration: duration
     }}
  end

  @impl Ground
  @spec schedule(Group.t(), (pos_integer() -> non_neg_integer())) :: {:ok, Group.t()}
  def schedule(%Group{created_at: created} = group, _rng) do
    {:ok,
     %{
       group
       | next_tick_at: created + @open_delay,
         state: %{group.state | opens_at: created + @open_delay}
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()} | {:expire, Group.t()}
  def on_interval(%Group{} = group, now) do
    if now >= group.state.opens_at and not Map.get(group.state, :opened, false) do
      warp_occupants(%{group | state: Map.put(group.state, :opened, true)})
    else
      {:ok, group}
    end
  end

  defp warp_occupants(%Group{center: {cx, cy}, map_name: map_name} = group) do
    updated =
      map_name
      |> SpatialIndex.units_in_cell(cx, cy)
      |> Enum.reduce(group, fn
        {:player, player_id}, acc -> consume_warp(acc, player_id)
        _, acc -> acc
      end)

    if updated.state.uses <= 0, do: {:expire, updated}, else: {:ok, updated}
  end

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(%Group{} = group, {:player, player_id}) do
    if Map.get(group.state, :opened, false) and
         System.monotonic_time(:millisecond) >= group.state.opens_at do
      updated = consume_warp(group, player_id)
      if updated.state.uses <= 0, do: :expire, else: {:ok, updated}
    else
      {:ok, group}
    end
  end

  def on_touch(%Group{} = group, _mover), do: {:ok, group}

  defp consume_warp(%Group{state: %{uses: uses, dest: {map, x, y}} = state} = group, player_id)
       when uses > 0 do
    with false <- Map.get(state, :working, false),
         {:ok, {_module, target, pid}} <- UnitRegistry.get_unit(:player, player_id),
         true <- Unit.living?(target),
         nil <- target.waiting_room,
         true <- walk_destination(target) == group.center,
         true <- Targeting.placement_reaches?(definition(), {:player, player_id}) do
      working = target.map_name == map and {target.x, target.y} == {x, y}
      updated = %{group | state: state |> Map.put(:uses, uses - 1) |> Map.put(:working, working)}
      if PortalAccess.allowed?(target, map), do: PlayerSession.warp(pid, map, x, y)
      updated
    else
      _ -> group
    end
  end

  defp consume_warp(%Group{} = group, _player_id), do: group

  defp walk_destination(player),
    do: player.walk_target || List.last(player.walk_path || []) || {player.x, player.y}
end
