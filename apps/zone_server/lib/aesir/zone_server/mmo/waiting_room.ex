defmodule Aesir.ZoneServer.Mmo.WaitingRoom do
  @moduledoc """
  Shared in-memory store for NPC waiting rooms — the rooms an NPC opens above
  its head so players can gather, chat, and be warped out together.

  One room per owner NPC, keyed `{npc_gid, %WaitingRoom{}}` in the
  `:npc_waiting_rooms` table. Membership is an ordered list (join order, so the
  earliest joiner is first). Mutations are atomic compare-and-swap loops over the
  whole struct, mirroring `Aesir.ZoneServer.Mmo.StatusStorage`; reads are
  lock-free.

  The store performs no broadcasts and fires no events. Callers consult
  `fire_event?/1` and dispatch the event themselves, so this module stays a
  pure, testable data layer.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  defmodule Member do
    @moduledoc "A player currently in a waiting room."
    @enforce_keys [:char_id, :account_id, :name]
    defstruct [:char_id, :account_id, :name]

    @typedoc "A waiting-room member."
    @type t() :: %__MODULE__{
            char_id: integer(),
            account_id: integer(),
            name: String.t()
          }
  end

  @enforce_keys [:npc_gid, :title, :limit, :trigger, :event_ref, :zeny, :min_lvl, :max_lvl]
  defstruct npc_gid: nil,
            title: "",
            limit: 0,
            trigger: 0,
            event_ref: "",
            zeny: 0,
            min_lvl: 1,
            max_lvl: 99,
            enabled?: true,
            members: []

  @typedoc "A waiting room owned by an NPC."
  @type t() :: %__MODULE__{
          npc_gid: non_neg_integer(),
          title: String.t(),
          limit: pos_integer(),
          trigger: non_neg_integer(),
          event_ref: String.t(),
          zeny: non_neg_integer(),
          min_lvl: non_neg_integer(),
          max_lvl: non_neg_integer(),
          enabled?: boolean(),
          members: [Member.t()]
        }

  @doc """
  Creates a room for `npc_gid`, failing when it already has one.

  `limit` counts the owner NPC itself, so a limit of 8 admits 7 players.
  """
  @spec create(
          non_neg_integer(),
          String.t(),
          pos_integer(),
          non_neg_integer(),
          String.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: :ok | {:error, :already_exists}
  def create(npc_gid, title, limit, trigger, event_ref, zeny, min_lvl, max_lvl) do
    room = %__MODULE__{
      npc_gid: npc_gid,
      title: title,
      limit: limit,
      trigger: trigger,
      event_ref: event_ref,
      zeny: zeny,
      min_lvl: min_lvl,
      max_lvl: max_lvl
    }

    if :ets.insert_new(table(), {npc_gid, room}) do
      :ok
    else
      {:error, :already_exists}
    end
  end

  @doc """
  Appends `member` to `npc_gid`'s room, validating the room's capacity, level
  band, and zeny gate in precedence order (full, too low, too high, no zeny).
  """
  @spec join(non_neg_integer(), Member.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, t()} | {:error, :not_found | :full | :too_low_level | :too_high_level | :no_zeny}
  def join(npc_gid, member, base_level, zeny), do: join_loop(npc_gid, member, base_level, zeny)

  @doc "Removes `char_id` from the room, no-oping when absent."
  @spec leave(non_neg_integer(), integer()) :: :ok
  def leave(npc_gid, char_id) do
    _ =
      update(npc_gid, fn room ->
        %{room | members: Enum.reject(room.members, &(&1.char_id == char_id))}
      end)

    :ok
  end

  @doc "Removes the member named `char_name`, returning an error when absent."
  @spec kick(non_neg_integer(), String.t()) :: :ok | {:error, :not_found}
  def kick(npc_gid, char_name) do
    case Enum.find(members(npc_gid), &(&1.name == char_name)) do
      nil -> {:error, :not_found}
      member -> leave(npc_gid, member.char_id)
    end
  end

  @doc "Empties the room's membership, keeping the room itself."
  @spec kick_all(non_neg_integer()) :: :ok
  def kick_all(npc_gid) do
    _ = update(npc_gid, &%{&1 | members: []})
    :ok
  end

  @doc "Destroys the room entirely."
  @spec delete(non_neg_integer()) :: :ok
  def delete(npc_gid) do
    :ets.delete(table(), npc_gid)
    :ok
  end

  @doc """
  Re-enables the room's event trigger, returning the room so the caller can
  immediately re-check `fire_event?/1`.
  """
  @spec enable_event(non_neg_integer()) :: {:ok, t()} | :error
  def enable_event(npc_gid), do: update(npc_gid, &%{&1 | enabled?: true})

  @doc "Disables the room's event trigger; membership is untouched."
  @spec disable_event(non_neg_integer()) :: :ok
  def disable_event(npc_gid) do
    _ = update(npc_gid, &%{&1 | enabled?: false})
    :ok
  end

  @doc "Returns the room for `npc_gid`, or `:error` when absent."
  @spec get(non_neg_integer()) :: {:ok, t()} | :error
  def get(npc_gid) do
    case :ets.lookup(table(), npc_gid) do
      [{^npc_gid, room}] -> {:ok, room}
      [] -> :error
    end
  end

  @doc "Returns the room's members in join order, or `[]` when the room is absent."
  @spec members(non_neg_integer()) :: [Member.t()]
  def members(npc_gid) do
    case :ets.lookup(table(), npc_gid) do
      [{^npc_gid, room}] -> room.members
      [] -> []
    end
  end

  @doc """
  Answers the room's state for the given info `type`, or `-1` when the NPC has
  no room. Types: 0 users, 1 limit, 2 trigger, 3 disabled (0/1), 4 title,
  5 password (always empty), 16 event label, 32 full, 33 over-trigger.
  """
  @spec state(non_neg_integer(), integer()) :: term()
  def state(npc_gid, type) do
    case get(npc_gid) do
      {:ok, room} -> state_of(room, type)
      :error -> -1
    end
  end

  @doc "Whether the room's event should fire: enabled, has a label, and full enough."
  @spec fire_event?(t()) :: boolean()
  def fire_event?(%__MODULE__{} = room) do
    room.enabled? and room.event_ref != "" and length(room.members) >= room.trigger
  end

  defp table, do: table_for(:npc_waiting_rooms)

  defp join_loop(npc_gid, member, base_level, zeny) do
    with [{^npc_gid, room}] <- :ets.lookup(table(), npc_gid),
         :ok <- validate(room, base_level, zeny) do
      updated = %{room | members: room.members ++ [member]}

      if :ets.select_replace(table(), cas_spec(npc_gid, room, updated)) == 1 do
        {:ok, updated}
      else
        join_loop(npc_gid, member, base_level, zeny)
      end
    else
      [] -> {:error, :not_found}
      {:error, _reason} = error -> error
    end
  end

  defp validate(room, base_level, zeny) do
    cond do
      length(room.members) + 1 >= room.limit -> {:error, :full}
      base_level < room.min_lvl -> {:error, :too_low_level}
      base_level > room.max_lvl -> {:error, :too_high_level}
      zeny < room.zeny -> {:error, :no_zeny}
      true -> :ok
    end
  end

  # Generic compare-and-swap read-modify-write. `fun` returns the replacement
  # struct; the write only lands if the room is still byte-for-byte the struct
  # that was read, retrying on a lost race.
  defp update(npc_gid, fun), do: update_loop(npc_gid, fun)

  defp update_loop(npc_gid, fun) do
    case :ets.lookup(table(), npc_gid) do
      [{^npc_gid, room}] ->
        updated = fun.(room)

        if :ets.select_replace(table(), cas_spec(npc_gid, room, updated)) == 1 do
          {:ok, updated}
        else
          update_loop(npc_gid, fun)
        end

      [] ->
        :error
    end
  end

  defp cas_spec(npc_gid, current, replacement) do
    [
      {{npc_gid, :"$1"}, [{:"=:=", :"$1", {:const, current}}], [{:const, {npc_gid, replacement}}]}
    ]
  end

  defp state_of(room, 0), do: length(room.members)
  defp state_of(room, 1), do: room.limit
  defp state_of(room, 2), do: room.trigger
  defp state_of(room, 3), do: if(room.enabled?, do: 0, else: 1)
  defp state_of(room, 4), do: room.title
  defp state_of(_room, 5), do: ""
  defp state_of(room, 16), do: room.event_ref
  defp state_of(room, 32), do: if(length(room.members) >= room.limit, do: 1, else: 0)

  defp state_of(room, 33),
    do: if(room.enabled? and length(room.members) >= room.trigger, do: 1, else: 0)

  defp state_of(_room, _type), do: -1
end
