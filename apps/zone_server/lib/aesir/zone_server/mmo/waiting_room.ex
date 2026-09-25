defmodule Aesir.ZoneServer.Mmo.WaitingRoom do
  @moduledoc """
  Shared in-memory store for chat rooms, the bubbles drawn above an owner's head
  so players can gather and talk. A room is owned by either an NPC or a player.

  - **NPC rooms** are opened by scripts. They are keyed by the NPC gid
    (`room_id == npc_gid`), always public and passwordless, count the NPC itself
    against the limit, carry the script trigger/event fields, and persist when
    empty.
  - **Player rooms** get an allocated id above `0x5800_0000`. The owner is member
    slot 0 and counts against the limit. When the owner leaves, the next-earliest
    member takes over; when the last member leaves, the room is destroyed. They
    support a password, a public flag, and a kick list that bars kicked players
    from rejoining.

  Rows live in the `:waiting_rooms` table as `{room_id, %WaitingRoom{}}`, plus a
  `{:next_id, n}` counter row for player room ids. Membership is an ordered list
  (join order). Mutations are atomic compare-and-swap loops over the whole
  struct, mirroring `Aesir.ZoneServer.Mmo.StatusStorage`; reads are lock-free.

  The store performs no broadcasts and fires no events. Callers consult
  `fire_event?/1` and dispatch the event themselves, so this module stays a
  pure, testable data layer.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Config

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

  @player_room_id_base 0x5800_0000
  @max_users 20
  @title_bytes 60
  @pass_bytes 8

  @typedoc "Who owns a room: an NPC by gid or a player by char id."
  @type owner :: {:npc, non_neg_integer()} | {:player, integer()}

  @typedoc "A room id: the NPC gid for NPC rooms, an allocated id for player rooms."
  @type room_id :: non_neg_integer()

  @typedoc "Why a join was refused."
  @type join_error ::
          :not_found
          | :full
          | :wrong_password
          | :too_low_level
          | :too_high_level
          | :no_zeny
          | :kicked

  @enforce_keys [:room_id, :owner, :title, :limit]
  defstruct room_id: nil,
            owner: nil,
            title: "",
            limit: 0,
            trigger: 0,
            event_ref: "",
            zeny: 0,
            min_lvl: 1,
            max_lvl: 99,
            pass: "",
            public?: true,
            enabled?: true,
            members: [],
            kick_list: MapSet.new()

  @typedoc "A chat room owned by an NPC or a player."
  @type t() :: %__MODULE__{
          room_id: room_id(),
          owner: owner(),
          title: String.t(),
          limit: pos_integer(),
          trigger: non_neg_integer(),
          event_ref: String.t(),
          zeny: non_neg_integer(),
          min_lvl: non_neg_integer(),
          max_lvl: non_neg_integer(),
          pass: String.t(),
          public?: boolean(),
          enabled?: boolean(),
          members: [Member.t()],
          kick_list: MapSet.t(integer())
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
      room_id: npc_gid,
      owner: {:npc, npc_gid},
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
  Creates a player room with `member` as owner and sole member.

  The title is truncated to 60 bytes and the password to 8 bytes (never splitting
  a character), and the limit is clamped to 1..20. The limit counts the owner.
  """
  @spec create_player_room(Member.t(), String.t(), String.t(), non_neg_integer(), boolean()) ::
          {:ok, t()}
  def create_player_room(%Member{} = member, title, pass, limit, public?) do
    room_id = next_player_room_id()

    room = %__MODULE__{
      room_id: room_id,
      owner: {:player, member.char_id},
      title: truncate(title, @title_bytes),
      pass: truncate(pass, @pass_bytes),
      limit: clamp_limit(limit),
      public?: public?,
      max_lvl: Config.max_base_level(),
      members: [member]
    }

    true = :ets.insert_new(table(), {room_id, room})
    {:ok, room}
  end

  @doc """
  Appends `member` to the room, validating in precedence order: full, wrong
  password, too low level, too high level, not enough zeny, kicked.

  The password only matters for private rooms. Pass `bypass_password: true` in
  `opts` to skip the password check (GM override).
  """
  @spec join(room_id(), Member.t(), non_neg_integer(), non_neg_integer(), String.t(), keyword()) ::
          {:ok, t()} | {:error, join_error()}
  def join(room_id, %Member{} = member, base_level, zeny, pass, opts) do
    with [{^room_id, room}] <- :ets.lookup(table(), room_id),
         :ok <- validate(room, member, base_level, zeny, pass, opts) do
      updated = %{room | members: room.members ++ [member]}

      if cas(room_id, room, updated) do
        {:ok, updated}
      else
        join(room_id, member, base_level, zeny, pass, opts)
      end
    else
      [] -> {:error, :not_found}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  Removes `char_id` from the room and reports what happened, decided by a single
  compare-and-swap:

  - `{:ok, :left}`: the member was removed (or was not a member).
  - `{:ok, {:owner_changed, next}}`: the player owner left and `next` owns the room.
  - `{:ok, :destroyed}`: the last member of a player room left; the room is gone.
  - `:error`: no such room.

  NPC rooms are never destroyed by leaving.
  """
  @spec leave(room_id(), integer()) ::
          {:ok, :left | {:owner_changed, Member.t()} | :destroyed} | :error
  def leave(room_id, char_id) do
    case :ets.lookup(table(), room_id) do
      [] ->
        :error

      [{^room_id, room}] ->
        remaining = Enum.reject(room.members, &(&1.char_id == char_id))
        leave_outcome(room_id, room, remaining, char_id)
    end
  end

  defp leave_outcome(room_id, %{owner: {:player, _}} = room, [], char_id) do
    if :ets.select_delete(table(), cas_delete_spec(room_id, room)) == 1,
      do: {:ok, :destroyed},
      else: leave(room_id, char_id)
  end

  defp leave_outcome(
         room_id,
         %{owner: {:player, char_id}} = room,
         [next | _] = remaining,
         char_id
       ) do
    updated = %{room | members: remaining, owner: {:player, next.char_id}}

    if cas(room_id, room, updated),
      do: {:ok, {:owner_changed, next}},
      else: leave(room_id, char_id)
  end

  defp leave_outcome(room_id, room, remaining, char_id) do
    if cas(room_id, room, %{room | members: remaining}),
      do: {:ok, :left},
      else: leave(room_id, char_id)
  end

  @doc """
  Removes the member named `char_name` and returns them. Player rooms also add
  them to the kick list so they cannot rejoin.
  """
  @spec kick(room_id(), String.t()) :: {:ok, Member.t()} | {:error, :not_found}
  def kick(room_id, char_name) do
    with [{^room_id, room}] <- :ets.lookup(table(), room_id),
         %Member{} = member <- Enum.find(room.members, &(&1.name == char_name)) do
      updated = %{
        room
        | members: List.delete(room.members, member),
          kick_list: add_to_kick_list(room, member.char_id)
      }

      if cas(room_id, room, updated), do: {:ok, member}, else: kick(room_id, char_name)
    else
      _ -> {:error, :not_found}
    end
  end

  defp add_to_kick_list(%{owner: {:player, _}, kick_list: kick_list}, char_id),
    do: MapSet.put(kick_list, char_id)

  defp add_to_kick_list(%{kick_list: kick_list}, _char_id), do: kick_list

  @doc """
  Hands a player room to the member named `next_name`, swapping them into slot 0.
  Only the current owner may do this.
  """
  @spec change_owner(room_id(), integer(), String.t()) ::
          {:ok, t()} | {:error, :not_owner | :not_found}
  def change_owner(room_id, owner_char_id, next_name) do
    owner_update(room_id, owner_char_id, fn room ->
      case Enum.find_index(room.members, &(&1.name == next_name)) do
        nil ->
          {:error, :not_found}

        index ->
          next = Enum.at(room.members, index)
          owner = hd(room.members)

          members =
            room.members |> List.replace_at(0, next) |> List.replace_at(index, owner)

          {:ok, %{room | members: members, owner: {:player, next.char_id}}}
      end
    end)
  end

  @doc """
  Edits a player room's title, password, limit, and public flag, applying the
  same truncation and clamping as `create_player_room/5`. Only the owner may do
  this.
  """
  @spec change_status(room_id(), integer(), String.t(), String.t(), non_neg_integer(), boolean()) ::
          {:ok, t()} | {:error, :not_owner | :not_found}
  def change_status(room_id, owner_char_id, title, pass, limit, public?) do
    owner_update(room_id, owner_char_id, fn room ->
      {:ok,
       %{
         room
         | title: truncate(title, @title_bytes),
           pass: truncate(pass, @pass_bytes),
           limit: clamp_limit(limit),
           public?: public?
       }}
    end)
  end

  @doc "Whether `char_id` is the player owning `room`. Always false for NPC rooms."
  @spec owner?(t(), integer()) :: boolean()
  def owner?(%__MODULE__{owner: owner}, char_id), do: owner == {:player, char_id}

  @doc "Slots taken in the room: members, plus one for the NPC in NPC rooms."
  @spec occupancy(t()) :: non_neg_integer()
  def occupancy(%__MODULE__{owner: {:npc, _}, members: members}), do: length(members) + 1
  def occupancy(%__MODULE__{members: members}), do: length(members)

  @doc "Empties the room's membership, keeping the room itself."
  @spec kick_all(room_id()) :: :ok
  def kick_all(room_id) do
    _ = update(room_id, &%{&1 | members: []})
    :ok
  end

  @doc "Destroys the room entirely."
  @spec delete(room_id()) :: :ok
  def delete(room_id) do
    :ets.delete(table(), room_id)
    :ok
  end

  @doc """
  Re-enables the room's event trigger, returning the room so the caller can
  immediately re-check `fire_event?/1`.
  """
  @spec enable_event(room_id()) :: {:ok, t()} | :error
  def enable_event(room_id), do: update(room_id, &%{&1 | enabled?: true})

  @doc "Disables the room's event trigger; membership is untouched."
  @spec disable_event(room_id()) :: :ok
  def disable_event(room_id) do
    _ = update(room_id, &%{&1 | enabled?: false})
    :ok
  end

  @doc "Returns the room for `room_id`, or `:error` when absent."
  @spec get(room_id()) :: {:ok, t()} | :error
  def get(room_id) do
    case :ets.lookup(table(), room_id) do
      [{^room_id, %__MODULE__{} = room}] -> {:ok, room}
      _ -> :error
    end
  end

  @doc "Returns the room's members in join order, or `[]` when the room is absent."
  @spec members(room_id()) :: [Member.t()]
  def members(room_id) do
    case get(room_id) do
      {:ok, room} -> room.members
      :error -> []
    end
  end

  @doc """
  Answers the room's state for the given info `type`, or `-1` when the NPC has
  no room. Types: 0 users, 1 limit, 2 trigger, 3 disabled (0/1), 4 title,
  5 password (always empty), 16 event label, 32 full, 33 over-trigger.
  """
  @spec state(room_id(), integer()) :: term()
  def state(room_id, type) do
    case get(room_id) do
      {:ok, room} -> state_of(room, type)
      :error -> -1
    end
  end

  @doc "Whether the room's event should fire: enabled, has a label, and full enough."
  @spec fire_event?(t()) :: boolean()
  def fire_event?(%__MODULE__{} = room) do
    room.enabled? and room.event_ref != "" and length(room.members) >= room.trigger
  end

  defp table, do: table_for(:waiting_rooms)

  defp next_player_room_id do
    @player_room_id_base + :ets.update_counter(table(), :next_id, 1, {:next_id, 0})
  end

  defp validate(room, member, base_level, zeny, pass, opts) do
    cond do
      occupancy(room) >= room.limit -> {:error, :full}
      wrong_password?(room, pass, opts) -> {:error, :wrong_password}
      base_level < room.min_lvl -> {:error, :too_low_level}
      base_level > room.max_lvl -> {:error, :too_high_level}
      zeny < room.zeny -> {:error, :no_zeny}
      MapSet.member?(room.kick_list, member.char_id) -> {:error, :kicked}
      true -> :ok
    end
  end

  defp wrong_password?(%{public?: true}, _pass, _opts), do: false

  defp wrong_password?(room, pass, opts),
    do: pass != room.pass and not Keyword.get(opts, :bypass_password, false)

  defp clamp_limit(limit), do: limit |> max(1) |> min(@max_users)

  defp truncate(string, max_bytes) when byte_size(string) <= max_bytes, do: string

  defp truncate(string, max_bytes) do
    string
    |> String.codepoints()
    |> Enum.reduce_while("", fn codepoint, acc ->
      if byte_size(acc) + byte_size(codepoint) > max_bytes,
        do: {:halt, acc},
        else: {:cont, acc <> codepoint}
    end)
  end

  # Owner-only compare-and-swap: `fun` returns `{:ok, updated}` or an error that
  # aborts without writing.
  defp owner_update(room_id, owner_char_id, fun) do
    with {:ok, room} <- fetch(room_id),
         :ok <- ensure_owner(room, owner_char_id),
         {:ok, updated} <- fun.(room) do
      if cas(room_id, room, updated),
        do: {:ok, updated},
        else: owner_update(room_id, owner_char_id, fun)
    end
  end

  defp fetch(room_id) do
    case get(room_id) do
      {:ok, room} -> {:ok, room}
      :error -> {:error, :not_found}
    end
  end

  defp ensure_owner(room, char_id),
    do: if(owner?(room, char_id), do: :ok, else: {:error, :not_owner})

  # Generic compare-and-swap read-modify-write. `fun` returns the replacement
  # struct; the write only lands if the room is still byte-for-byte the struct
  # that was read, retrying on a lost race.
  defp update(room_id, fun) do
    case get(room_id) do
      {:ok, room} ->
        updated = fun.(room)
        if cas(room_id, room, updated), do: {:ok, updated}, else: update(room_id, fun)

      :error ->
        :error
    end
  end

  defp cas(room_id, current, replacement),
    do: :ets.select_replace(table(), cas_spec(room_id, current, replacement)) == 1

  defp cas_spec(room_id, current, replacement) do
    [
      {{room_id, :"$1"}, [{:"=:=", :"$1", {:const, current}}], [{:const, {room_id, replacement}}]}
    ]
  end

  defp cas_delete_spec(room_id, current) do
    [{{room_id, :"$1"}, [{:"=:=", :"$1", {:const, current}}], [true]}]
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
