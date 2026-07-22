defmodule Aesir.ZoneServer.Unit.Mob.MvpReward do
  @moduledoc """
  MVP reward granting for a boss kill, called synchronously from
  `Aesir.ZoneServer.Unit.Mob.MobSession.announce_kill/2` while the dying mob
  still holds its full damage log.

  MVP tier is **derived, not stored**: a mob is MVP-tier when it carries MVP
  experience or at least one MVP drop entry. Most of the boss-classified mobs
  are mini-bosses, which fall out of `grant/5` on that single comparison.

  The winner is the single highest damage dealer among the contributors
  `Aesir.ZoneServer.Unit.Mob.KillExp.eligible_damage/2` considers eligible
  (online, alive, still on the mob's map), so the two reward paths cannot
  disagree about who counts as a contributor. A logged-out top contributor
  therefore falls through to the next highest automatically.

  The winner receives base-only MVP experience (the job component is always
  zero) and at most one MVP drop: the entries are rolled **in order and the
  roll stops at the first success**. Both are scaled by the MVP level-penalty
  tables.
  """

  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @max_rate 10_000
  @task_supervisor Aesir.ZoneServer.TaskSupervisor

  @typep winner ::
           {char_id :: non_neg_integer(), name :: String.t(), base_level :: integer(), pid()}

  @doc """
  Grants the MVP reward for the kill of `mob_data` at `{x, y}` on `map_name`.

  `aggro_list` is the mob's full cumulative `char_id => damage` log. No-ops
  entirely for non-MVP-tier mobs. Returns `:ok`.
  """
  @spec grant(
          %{non_neg_integer() => pos_integer()},
          MobDefinition.t(),
          String.t(),
          integer(),
          integer()
        ) :: :ok
  def grant(_aggro_list, %MobDefinition{mvp_exp: 0, mvp_drops: []}, _map_name, _x, _y), do: :ok

  def grant(aggro_list, %MobDefinition{} = mob_data, map_name, x, y)
      when map_size(aggro_list) > 0 do
    winner = pick_winner(aggro_list, map_name)

    grant_exp(winner, mob_data)
    grant_drop(winner, mob_data, map_name, x, y)
    announce(winner, mob_data)

    :ok
  end

  def grant(_aggro_list, %MobDefinition{}, _map_name, _x, _y), do: :ok

  @spec pick_winner(%{non_neg_integer() => pos_integer()}, String.t()) :: winner() | nil
  defp pick_winner(aggro_list, map_name) do
    aggro_list
    |> KillExp.eligible_damage(map_name)
    |> Enum.max_by(fn {_char_id, damage} -> damage end, fn -> nil end)
    |> case do
      nil -> nil
      {char_id, _damage} -> resolve_winner(char_id)
    end
  end

  @spec resolve_winner(non_neg_integer()) :: winner() | nil
  defp resolve_winner(char_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, player_state, pid}} ->
        {char_id, player_state.character_name, player_state.stats.progression.base_level, pid}

      {:error, :not_found} ->
        nil
    end
  end

  @spec grant_exp(winner() | nil, MobDefinition.t()) :: :ok
  defp grant_exp(nil, _mob_data), do: :ok
  defp grant_exp(_winner, %MobDefinition{mvp_exp: 0}), do: :ok

  defp grant_exp({char_id, _name, base_level, _pid}, %MobDefinition{
         mvp_exp: mvp_exp,
         level: level,
         race: race
       }) do
    rate = LevelPenalty.mvp_exp(level, base_level)

    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{char_id}",
      {:progression, {:mob_kill_exp, scale(mvp_exp, rate), 0, race}}
    )

    :ok
  end

  # Rolls the MVP drop table in order, stopping at the first success, and hands
  # the winning item to the MVP through the player session's single-writer
  # `{:npc, {:script_apply, op}}` seam (which itself runs `InventoryOps.add/6`). A full
  # inventory -- or no MVP left to receive it -- scatters the item onto the
  # death cell instead.
  @spec grant_drop(winner() | nil, MobDefinition.t(), String.t(), integer(), integer()) :: :ok
  defp grant_drop(winner, %MobDefinition{mvp_drops: drops, level: level}, map_name, x, y) do
    case roll(drops, level, base_level(winner, level)) do
      nil -> :ok
      nameid -> deliver(winner, nameid, map_name, x, y)
    end
  end

  @spec roll([MobDrop.t()], integer(), integer()) :: non_neg_integer() | nil
  defp roll(drops, mob_level, base_level) do
    rate = LevelPenalty.mvp_drop(mob_level, base_level)

    Enum.find_value(drops, fn %MobDrop{item: aegis, rate: base} ->
      with {:ok, %ItemDefinition{id: nameid}} <- Items.by_aegis(aegis),
           true <- :rand.uniform(@max_rate) <= min(div(base * rate, 100), @max_rate) do
        nameid
      else
        _ -> nil
      end
    end)
  end

  # Delivery runs off the mob process. `TF_Steal` and `SA_Spellbreaker` both
  # call *into* a `MobSession` from the attacker's own `PlayerSession`, so a
  # `GenServer.call` issued from the dying mob would deadlock against an
  # in-flight one of those until both sides time out and crash.
  @spec deliver(winner() | nil, non_neg_integer(), String.t(), integer(), integer()) :: :ok
  defp deliver(nil, nameid, map_name, x, y), do: scatter(nameid, map_name, x, y)

  defp deliver({_char_id, _name, _base_level, pid}, nameid, map_name, x, y) do
    {:ok, _pid} =
      Task.Supervisor.start_child(@task_supervisor, fn ->
        case give_item(pid, nameid) do
          :ok -> :ok
          {:error, _reason} -> scatter(nameid, map_name, x, y)
        end
      end)

    :ok
  end

  # A winner who logs out or crashes between the registry lookup and this call
  # makes `GenServer.call` *exit* rather than reply, which would kill the task
  # and lose the drop entirely. Both failure shapes have to reach the same floor
  # fallback, so the exit is caught and normalized into an error tuple.
  @spec give_item(pid(), non_neg_integer()) :: :ok | {:error, term()}
  defp give_item(pid, nameid) do
    case PlayerSession.script_apply(pid, {:give_item, nameid, 1}) do
      {:error, reason} -> {:error, reason}
      _delivered -> :ok
    end
  catch
    :exit, reason -> {:error, reason}
  end

  @spec scatter(non_neg_integer(), String.t(), integer(), integer()) :: :ok
  defp scatter(nameid, map_name, x, y) do
    Coordinator.drop_items(map_name, [{nameid, 1, x, y}], x, y)
  end

  @spec base_level(winner() | nil, integer()) :: integer()
  defp base_level(nil, mob_level), do: mob_level
  defp base_level({_char_id, _name, base_level, _pid}, _mob_level), do: base_level

  @spec announce(winner() | nil, MobDefinition.t()) :: :ok
  defp announce(nil, _mob_data), do: :ok

  defp announce({_char_id, name, _base_level, _pid}, %MobDefinition{name: mob_name}) do
    Announcement.to_all(%{
      text: "#{name} has defeated #{mob_name}!",
      color: 0,
      style: Flags.style_for(:all),
      source_name: ""
    })

    :ok
  end

  @spec scale(non_neg_integer(), integer()) :: non_neg_integer()
  defp scale(amount, rate) do
    case div(amount * rate, 100) do
      0 when amount > 0 -> 1
      scaled -> scaled
    end
  end
end
