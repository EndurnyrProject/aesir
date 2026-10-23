defmodule Aesir.ZoneServer.Unit.Player.Handlers.LootHandler do
  @moduledoc """
  Kill-reward glue for a player session: drop rolling for the killing blow's
  reward owner (`{:mob_killed, ...}`) and quest kill credit with its extra
  quest drops (`{:quest_kill, ...}`).
  """

  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.ItemDrop.DropCalculator
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Production.OreTable
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Network.MessageRouter
  alias Aesir.ZoneServer.Unit.Player.Handlers.HealthHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.QuestInfoView
  alias Aesir.ZoneServer.Unit.Player.QuestLog
  alias Aesir.ZoneServer.Unit.Player.QuestPersistence
  alias Aesir.ZoneServer.Unit.Player.QuestView
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats

  @finding_ore 106

  @doc """
  Routes a `:loot`-enveloped session message to its handler. `PlayerSession`'s
  single `handle_info({:loot, msg}, state)` clause delegates here; each head
  returns the GenServer-native `{:noreply, state}` tuple.
  """
  @spec info(term(), map()) :: {:noreply, map()}
  def info({:mob_killed, payload}, state), do: mob_killed(payload, state)
  def info({:kill_gain, payload}, state), do: kill_gain_reward(payload, state)
  def info({:quest_kill, kill}, state), do: quest_kill(kill, state)

  @doc """
  EXP for the kill is granted separately, per eligible typed contributor, via
  `{:progression, {:mob_kill_exp, base, job, mob_race, mob_class}}`
  (`Unit.Mob.KillExp.distribute_typed/7`); this handler only rolls and places
  this reward-owner session's drops. Ore Discovery additionally requires an
  actual player final source.
  """
  @spec mob_killed(map(), map()) :: {:noreply, map()}
  def mob_killed(payload, state), do: mob_killed(payload, state, &:rand.uniform/1)

  @doc false
  @spec mob_killed(map(), map(), (pos_integer() -> pos_integer())) :: {:noreply, map()}
  def mob_killed(payload, state, rng) do
    maybe_drop_items(payload, state, rng)
    {:noreply, maybe_credit_zeny(payload, state, rng)}
  end

  defp maybe_credit_zeny(%{mob_level: mob_level}, state, rng) do
    case Map.get(state.game_state.stats.modifiers.equipment, :get_zeny) do
      {rate, amount} when rate > 0 and amount != 0 ->
        credit_random_zeny(rate, amount, mob_level, state, rng)

      _missing ->
        state
    end
  end

  defp maybe_credit_zeny(_payload, state, _rng), do: state

  defp credit_random_zeny(rate, amount, mob_level, state, rng) do
    if rng.(100) <= min(rate, 100) do
      max_amount = if amount > 0, do: amount, else: -mob_level * amount

      {_reply, state} =
        ScriptEffectHandler.apply_op({:credit_zeny, rng.(max(max_amount, 1))}, state)

      state
    else
      state
    end
  end

  @doc """
  Grants the killing player the on-kill HP/SP gain equipment bonuses matching
  the killing blow's attack type (`{:loot, {:kill_gain, ...}}`, broadcast
  independently of drops).

  Only the player's own killing blow counts — a homunculus/slave kill credits
  the owner's rewards but not their on-kill gain — and only weapon/magic blows
  are eligible. Learned passives add flat SP on top (`Passives.kill_sp_gain/2`,
  Soul Drain). The heal is a raw forced grant (no received-heal scaling).
  """
  @spec kill_gain_reward(map(), map()) :: {:noreply, map()}
  def kill_gain_reward(%{final_source: {:player, char_id}, kill_bf: kill_bf} = payload, state)
      when kill_bf in [:melee, :ranged, :magic] do
    if char_id == state.game_state.character_id do
      stats = state.game_state.stats
      {hp, sp} = kill_gain(kill_bf, stats.modifiers.equipment, Map.get(payload, :mob_race))

      kill = %{
        kill_bf: kill_bf,
        skill_id: Map.get(payload, :skill_id),
        mob_level: Map.get(payload, :mob_level, 0)
      }

      sp = sp + Passives.kill_sp_gain(stats, kill)

      {:noreply, state} = HealthHandler.gain_hp(hp, state)
      HealthHandler.restore_sp(sp, state)
    else
      {:noreply, state}
    end
  end

  def kill_gain_reward(_payload, state), do: {:noreply, state}

  defp kill_gain(:melee, equipment, mob_race) do
    {Map.get(equipment, :hp_gain_value, 0),
     Map.get(equipment, :sp_gain_value, 0) + sp_gain_race(equipment, mob_race)}
  end

  defp kill_gain(:ranged, equipment, _mob_race) do
    {0, Map.get(equipment, :long_sp_gain_value, 0)}
  end

  defp kill_gain(:magic, equipment, _mob_race) do
    {Map.get(equipment, :magic_hp_gain_value, 0), Map.get(equipment, :magic_sp_gain_value, 0)}
  end

  defp sp_gain_race(equipment, mob_race) do
    race = bonus_race(mob_race)

    Map.get(equipment, {:sp_gain_race, race}, 0) +
      Map.get(equipment, {:sp_gain_race, :all}, 0)
  end

  @doc """
  Credits a monster kill against this session's not-complete quests
  (`Unit.Mob.QuestHuntCredit`), one quest at a time in walk order.

  For each quest the matching objectives move (`QuestLog.tick_quest/3`, judged
  on this player's map), the moved quest is written through to
  `character_quests` with one `QuestHuntProgress` per moved objective, and
  then each of the quest's drop rows for this monster is granted: a row below
  10000 is rolled out of 10000, an unknown item is skipped, and one item is
  added whatever the row's count, identified as the item's obtain rule says,
  with a refused add reported as an `ItemAddFailed`. With any not-complete
  quest the map's quest icons are re-evaluated afterwards. A player with none
  is untouched.
  """
  @spec quest_kill(map(), map()) :: {:noreply, map()}
  def quest_kill(kill, state), do: quest_kill(kill, state, &:rand.uniform/1)

  @doc false
  @spec quest_kill(map(), map(), (pos_integer() -> pos_integer())) :: {:noreply, map()}
  def quest_kill(kill, %{game_state: game_state} = state, rng) do
    case QuestLog.available(game_state.quest_log) do
      [] ->
        {:noreply, state}

      quests ->
        kill = Map.put(kill, :map, game_state.map_name)

        state =
          Enum.reduce(quests, state, fn {quest_id, _entry}, state ->
            state
            |> credit_quest_objectives(quest_id, kill)
            |> grant_quest_drops(quest_id, kill.mob_id, rng)
          end)

        QuestInfoView.request_refresh()
        {:noreply, state}
    end
  end

  defp credit_quest_objectives(%{game_state: game_state} = state, quest_id, kill) do
    case QuestLog.tick_quest(game_state.quest_log, quest_id, kill) do
      {_quest_log, []} ->
        state

      {quest_log, changes} ->
        QuestPersistence.upsert(
          game_state.character_id,
          {quest_id, Map.fetch!(quest_log, quest_id)}
        )

        push_quest_progress(state.connection_pid, changes)
        StateCommit.commit(state, %{game_state | quest_log: quest_log})
    end
  end

  defp grant_quest_drops(state, quest_id, mob_id, rng) do
    quest_id
    |> QuestLog.drops_for_kill(mob_id)
    |> Enum.reduce(state, &grant_quest_drop(&1, &2, rng))
  end

  defp grant_quest_drop(%{item_id: item_id, rate: rate}, state, rng) do
    with true <- rate >= 10_000 or rng.(10_000) <= rate,
         {:ok, item} <- ItemManagement.get_item_by_id(item_id) do
      identify = if ItemDefinition.identified_on_obtain?(item), do: 1, else: 0
      settle_quest_drop(InventoryManager.handle_give_item(item, 1, state, %{identify: identify}))
    else
      _skipped -> state
    end
  end

  defp settle_quest_drop({:ok, state}), do: state
  defp settle_quest_drop({:error, _reason, state}), do: state

  # Rolls the slain mob's drop table from the reward owner's session (the only
  # place holding both the table and the reward owner's stats) and places results as
  # ground items through the map coordinator. Legacy payloads without a drop
  # table fall through to the no-op clause.
  defp maybe_drop_items(%{ownership: ownership, boss?: boss?} = payload, state, rng) do
    maybe_drop_items(payload, state, rng, ownership: {ownership, boss?})
  end

  defp maybe_drop_items(payload, state, rng), do: maybe_drop_items(payload, state, rng, [])

  defp maybe_drop_items(
         %{drops: drops, mob_level: mob_level, map: map, x: x, y: y} = payload,
         state,
         rng,
         opts
       ) do
    stats = state.game_state.stats
    luk = Stats.get_effective_stat(stats, :luk)
    base_level = stats.progression.base_level
    char_id = state.game_state.character_id

    drop_bonus =
      :player
      |> ModifierCalculator.get_all_modifiers(char_id)
      |> Map.get(:drop_rate, 0)
      |> Kernel.+(drop_add_race(stats.modifiers.equipment, Map.get(payload, :mob_race)))

    equip_drops =
      DropCalculator.roll_equipment_drops(
        stats.modifiers.equipment,
        Map.get(payload, :mob_race),
        Map.get(payload, :mob_id),
        map,
        x,
        y
      )

    items =
      drops
      |> DropCalculator.roll(luk, base_level, mob_level, drop_bonus, map, x, y,
        fixed_item_drop: Map.get(payload, :fixed_item_drop?, false)
      )
      |> Kernel.++(equip_drops)
      |> maybe_discover_ore(
        Stats.skill_level(stats, @finding_ore),
        x,
        y,
        rng,
        Map.get(payload, :final_source, {:player, char_id})
      )

    items = items ++ DropCalculator.scatter_loot(Map.get(payload, :looted_items, []), map, x, y)

    case {items, opts} do
      {[], _opts} -> :ok
      {items, []} -> Coordinator.drop_items(map, items, x, y)
      {items, opts} -> Coordinator.drop_items(map, items, x, y, opts)
    end
  end

  defp maybe_drop_items(_payload, _state, _rng, _opts), do: :ok

  defp drop_add_race(equipment, mob_race) do
    race = bonus_race(mob_race)

    Map.get(equipment, {:drop_add_race, race}, 0) +
      Map.get(equipment, {:drop_add_race, :all}, 0)
  end

  defp bonus_race(:player), do: RaceModifiers.player_race()
  defp bonus_race(race) when is_atom(race), do: race

  defp maybe_discover_ore(drops, finding_ore_level, x, y, rng, {:player, _id}) do
    if finding_ore_level > 0 do
      entries = OreTable.entries()
      {item_id, rate} = Enum.fetch!(entries, rng.(length(entries)) - 1)

      if rng.(10_000) <= rate,
        do: drops ++ [{item_id, 1, x, y, identified_on_obtain(item_id)}],
        else: drops
    else
      drops
    end
  end

  defp maybe_discover_ore(drops, _finding_ore_level, _x, _y, _rng, _final_source), do: drops

  # Ore discovery builds its item through the same drop-item construction as
  # the monster's table, so the obtain rule decides identification. An
  # unresolvable id is an ETC item there, which is identified.
  defp identified_on_obtain(item_id) do
    case ItemManagement.get_item_by_id(item_id) do
      {:ok, item} -> ItemDefinition.identified_on_obtain?(item)
      {:error, _reason} -> true
    end
  end

  defp push_quest_progress(connection_pid, changes) do
    Enum.each(changes, fn change ->
      MessageRouter.send_to(connection_pid, QuestView.quest_hunt_progress(change))
    end)
  end
end
