defmodule Aesir.ZoneServer.Unit.Mob.MvpReward do
  @moduledoc """
  MVP reward granting for a boss kill, called synchronously from the mob
  death handler while the dying mob still holds its full damage log.

  MVP tier is **derived, not stored**: a mob is MVP-tier when it carries MVP
  experience or at least one MVP drop entry. Most of the boss-classified mobs
  are mini-bosses, which fall out of `grant/6` on that single comparison.

  The winner is the single highest damage dealer among the contributors
  `Aesir.ZoneServer.Unit.Mob.KillExp.eligible_damage/2` considers eligible
  (online, alive, still on the mob's map), so the two reward paths cannot
  disagree about who counts as a contributor. A logged-out top contributor
  therefore falls through to the next highest automatically.

  The winner receives base-only MVP experience (the job component is always
  zero) and at most one MVP drop: the entries are rolled **in order and the
  roll stops at the first success**. Both are scaled by the MVP level-penalty
  tables, except that a monster whose definition carries the fixed-item-drop
  mode keeps its fixed MVP drop rates: only the drop penalty is exempt, never
  the MVP experience penalty. A map flagged as forbidding MVP loot grants no
  MVP item at all, while its experience still lands.
  """

  alias Aesir.Commons.Models.ItemOptions
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.LevelPenalty
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @max_rate 10_000
  @no_penalty 100
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
          integer(),
          LootOwnership.t()
        ) :: :ok
  def grant(
        _aggro_list,
        %MobDefinition{mvp_exp: 0, mvp_drops: []},
        _map_name,
        _x,
        _y,
        _ownership
      ),
      do: :ok

  def grant(aggro_list, %MobDefinition{} = mob_data, map_name, x, y, ownership)
      when map_size(aggro_list) > 0 do
    winner = pick_winner(aggro_list, map_name)

    grant_exp(winner, mob_data)
    grant_drop(winner, mob_data, map_name, x, y, ownership)
    announce(winner, mob_data)

    :ok
  end

  def grant(_aggro_list, %MobDefinition{}, _map_name, _x, _y, _ownership), do: :ok

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
         race: race,
         modes: modes
       }) do
    rate = LevelPenalty.mvp_exp(level, base_level)
    mvp_exp = apply_rate(mvp_exp, Config.mvp_exp_rate())
    mob_class = MobMode.class(modes)

    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{char_id}",
      {:progression, {:mob_kill_exp, scale(mvp_exp, rate), 0, race, mob_class}}
    )

    :ok
  end

  # Rolls the MVP drop table in order, stopping at the first success, and hands
  # the winning item to the MVP through the player session's single-writer
  # `{:npc, {:script_apply, op}}` seam (which itself runs `InventoryOps.add/6`). A full
  # inventory -- or no MVP left to receive it -- scatters the item onto the
  # death cell instead.
  @spec grant_drop(
          winner() | nil,
          MobDefinition.t(),
          String.t(),
          integer(),
          integer(),
          LootOwnership.t()
        ) :: :ok
  defp grant_drop(
         winner,
         %MobDefinition{mvp_drops: drops, level: level, modes: modes},
         map_name,
         x,
         y,
         ownership
       ) do
    fixed_item_drop? = :fixed_item_drop in (modes || [])

    if MapFlags.get(map_name, :nomvploot) do
      :ok
    else
      case roll(drops, level, base_level(winner, level), fixed_item_drop?) do
        nil -> :ok
        grant -> deliver(winner, grant, map_name, x, y, ownership)
      end
    end
  end

  # The winning MVP drop: its item id, whether it arrives identified, and the
  # random options its drop row's group rolled.
  @typep drop_grant() :: {non_neg_integer(), boolean(), ItemOptions.t()}

  @spec roll([MobDrop.t()], integer(), integer(), boolean()) :: drop_grant() | nil
  defp roll(drops, mob_level, base_level, fixed_item_drop?) do
    penalty =
      if fixed_item_drop?, do: @no_penalty, else: LevelPenalty.mvp_drop(mob_level, base_level)

    server_rate = Config.item_drop_rate(:mvp)
    {min_rate, max_rate} = Config.item_drop_bounds(:mvp)

    Enum.find_value(drops, fn %MobDrop{item: aegis, rate: base} = drop ->
      rate =
        base
        |> apply_rate(server_rate)
        |> apply_rate(penalty)
        |> max(min_rate)
        |> min(max_rate)

      with {:ok, %ItemDefinition{} = item} <- Items.by_aegis(aegis),
           true <- :rand.uniform(@max_rate) <= rate do
        {item.id, ItemDefinition.identified_on_obtain?(item),
         RandomOptions.roll_named(drop.random_option_group)}
      else
        _ -> nil
      end
    end)
  end

  # Delivery runs off the mob process. `TF_Steal` and `SA_Spellbreaker` both
  # call *into* a `MobSession` from the attacker's own `PlayerSession`, so a
  # `GenServer.call` issued from the dying mob would deadlock against an
  # in-flight one of those until both sides time out and crash.
  @spec deliver(
          winner() | nil,
          drop_grant(),
          String.t(),
          integer(),
          integer(),
          LootOwnership.t()
        ) :: :ok
  defp deliver(nil, grant, map_name, x, y, ownership),
    do: scatter(grant, map_name, x, y, nil, ownership)

  defp deliver({_char_id, _name, _base_level, pid} = winner, grant, map_name, x, y, ownership) do
    {:ok, _pid} =
      Task.Supervisor.start_child(@task_supervisor, fn ->
        case give_item(pid, grant) do
          :ok -> :ok
          {:error, _reason} -> fail_drop(grant, map_name, x, y, winner, ownership)
        end
      end)

    :ok
  end

  # The give already told the MVP why the prize could not be carried (the
  # session's grant op emits the add-failure message); the reference still drops
  # it on that player's own cell, loot-protected for the kill's owners.
  defp fail_drop(grant, map_name, x, y, winner, ownership) do
    {drop_map, drop_x, drop_y} = winner_position(winner, map_name, x, y)
    scatter(grant, drop_map, drop_x, drop_y, winner, ownership)
  end

  defp winner_position({char_id, _name, _base_level, _pid}, fallback_map, fallback_x, fallback_y) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, player_state, _pid}} ->
        {
          Map.get(player_state, :map_name, fallback_map),
          Map.get(player_state, :x, fallback_x),
          Map.get(player_state, :y, fallback_y)
        }

      {:error, :not_found} ->
        {fallback_map, fallback_x, fallback_y}
    end
  end

  # A winner who logs out or crashes between the registry lookup and this call
  # makes `GenServer.call` *exit* rather than reply, which would kill the task
  # and lose the drop entirely. Both failure shapes have to reach the same floor
  # fallback, so the exit is caught and normalized into an error tuple.
  @spec give_item(pid(), drop_grant()) :: :ok | {:error, term()}
  defp give_item(pid, grant) do
    case PlayerSession.script_apply(pid, grant_op(grant)) do
      {:error, reason} -> {:error, reason}
      _delivered -> :ok
    end
  catch
    :exit, reason -> {:error, reason}
  end

  # An MVP drop the reference leaves unidentified, or one with random options,
  # needs the explicit-attribute grant; any other is the plain `getitem` shape.
  @spec grant_op(drop_grant()) :: tuple()
  defp grant_op({nameid, true, []}), do: {:give_item, nameid, 1}
  defp grant_op({nameid, false, []}), do: {:give_item2, nameid, 1, %{identify: 0}}

  defp grant_op({nameid, identified, options}),
    do:
      {:give_item2, nameid, 1,
       %{identify: if(identified, do: 1, else: 0), random_options: options}}

  @spec scatter(drop_grant(), String.t(), integer(), integer(), winner() | nil, LootOwnership.t()) ::
          :ok
  defp scatter({nameid, identified, options}, map_name, x, y, winner, ownership) do
    Coordinator.drop_items(
      map_name,
      [GroundItem.entry(nameid, 1, x, y, identified, options)],
      x,
      y,
      ownership: {fallback_ownership(winner, ownership), true}
    )
  end

  @spec fallback_ownership(winner() | nil, LootOwnership.t()) :: LootOwnership.t()
  defp fallback_ownership(nil, ownership), do: ownership

  defp fallback_ownership({recipient, _name, _base_level, _pid}, ownership) do
    [second, third | _] =
      [ownership.first, ownership.second, ownership.third]
      |> Enum.reject(&(&1 == recipient))
      |> Kernel.++([nil, nil])

    %LootOwnership{first: recipient, second: second, third: third}
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

  # Server rate multiplier (percentage) applied to an MVP reward amount. A 0
  # amount or 0 rate yields 0.
  @spec apply_rate(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  defp apply_rate(amount, 100), do: amount
  defp apply_rate(amount, rate), do: div(amount * rate, 100)
end
