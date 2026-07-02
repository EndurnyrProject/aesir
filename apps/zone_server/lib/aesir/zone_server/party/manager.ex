defmodule Aesir.ZoneServer.Party.Manager do
  @moduledoc """
  Facade owning the `{:party, party_id}` Horde entry, mirroring
  `Aesir.Commons.SessionManager`'s shape (design "Runtime state (zone_server)").

  The `parties` table plus `characters.party_id` are the persistence source of
  truth; the entry is the runtime working copy, lazily rebuilt from the DB via
  `ensure_started/1`. Covers lifecycle (create/rebuild/lookup/disband),
  membership mutations (join/leave/kick/leader transfer/options), and
  presence/level-spread tracking (`push_base_level/3`, `push_map_change/3`,
  `set_online/3`).
  """

  import Ecto.Query

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.Cluster.Entry
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Party
  alias Aesir.Repo
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State

  @doc """
  Creates a party led by `leader_character`, persists it (party row + the
  leader's `characters.party_id`) inside one transaction, and starts its
  runtime entry with the leader marked online.
  """
  @spec create(String.t(), Character.t()) ::
          {:ok, State.t()} | {:error, :name_taken | :invalid_name | term()}
  def create(name, %Character{} = leader_character) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :party,
        Party.changeset(%Party{}, %{name: name, leader_char_id: leader_character.id})
      )
      |> Ecto.Multi.update(:leader, fn %{party: party} ->
        Character.changeset(leader_character, %{party_id: party.id})
      end)

    case Repo.transaction(multi) do
      {:ok, %{party: party}} ->
        leader_member =
          Member.new(
            leader_character.id,
            leader_character.name,
            leader_character.base_level,
            true,
            leader_character.last_map
          )

        finish_create(party, [leader_member])

      {:error, :party, changeset, _changes} ->
        map_party_error(changeset)

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  defp finish_create(party, members) do
    state = build_state(party, members)

    case start_entry(key: {:party, party.id}, value: state) do
      :ok -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Ensures `{:party, party_id}` has a live entry, rebuilding it from the DB
  (party row + every `Character` row where `party_id` matches, all offline
  until each member's session pushes presence) when none is running.
  Idempotent -- a no-op returning the existing state if one already is.
  """
  @spec ensure_started(non_neg_integer()) :: {:ok, State.t()} | {:error, :not_found | term()}
  def ensure_started(party_id) do
    case get(party_id) do
      {:ok, state} -> {:ok, state}
      {:error, :not_found} -> rebuild_or_fetch(party_id)
    end
  end

  defp rebuild_or_fetch(party_id) do
    case rebuild(party_id) do
      {:error, :already_registered} -> get(party_id)
      other -> other
    end
  end

  defp rebuild(party_id) do
    case Repo.get(Party, party_id) do
      nil ->
        {:error, :not_found}

      party ->
        members =
          party_id
          |> characters_query()
          |> Repo.all()
          |> Enum.map(&Member.new(&1.id, &1.name, &1.base_level, false))

        finish_create(party, members)
    end
  end

  @doc """
  Reads the live entry for `party_id` without rebuilding it.
  """
  @spec get(non_neg_integer()) :: {:ok, State.t()} | {:error, :not_found}
  def get(party_id) do
    case Horde.Registry.lookup(Cluster.registry(), {:party, party_id}) do
      [{_pid, %State{} = state}] -> {:ok, state}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Disbands a party: resets `party_id` to `0` for every member row and deletes
  the `Party` row in one DB transaction, broadcasts `{:party_disbanded,
  party_id, reason}` on `"party:\#{party_id}"`, and stops the entry.
  """
  @spec disband(non_neg_integer(), String.t()) :: :ok | {:error, term()}
  def disband(party_id, reason) do
    case lookup_pid({:party, party_id}) do
      {:ok, pid} ->
        try do
          case Entry.get_and_update(pid, &disband_reply(party_id, &1)) do
            {:ok, _state} ->
              broadcast(party_id, {:party_disbanded, party_id, reason})
              stop_entry({:party, party_id})
              :ok

            {:error, _reason} = error ->
              error
          end
        catch
          :exit, _ -> {:error, :not_found}
        end

      :error ->
        {:error, :not_found}
    end
  end

  defp disband_reply(party_id, state) do
    case delete_party_and_reset_members(party_id) do
      :ok -> {{:ok, state}, state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp delete_party_and_reset_members(party_id) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.update_all(:reset_members, characters_query(party_id), set: [party_id: 0])
      |> Ecto.Multi.run(:party, fn repo, _changes ->
        case repo.get(Party, party_id) do
          nil -> {:error, :not_found}
          party -> repo.delete(party)
        end
      end)

    case Repo.transaction(multi) do
      {:ok, _changes} -> :ok
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  @doc """
  Adds `character` to `party_id`, re-validating inside the entry that the
  party is not full (`Party.State.full?/1`) and that no existing member
  shares `character.account_id` (design "Same-account rule"). Persists
  `characters.party_id` and broadcasts `{:party_updated, state}` on success;
  leaves the state and the character's row untouched on failure.
  """
  @spec add_member(non_neg_integer(), Character.t()) ::
          {:ok, State.t()} | {:error, :party_full | :same_account | :not_found | term()}
  def add_member(party_id, %Character{} = character) do
    mutate(party_id, &add_member_reply(character, &1))
  end

  defp add_member_reply(character, state) do
    cond do
      State.full?(state) ->
        {{:error, :party_full}, state}

      same_account_member?(state, character.account_id) ->
        {{:error, :same_account}, state}

      true ->
        case persist_add_member(state.party_id, character) do
          :ok ->
            new_state = put_member(state, character)
            {{:ok, new_state}, new_state}

          {:error, reason} ->
            {{:error, reason}, state}
        end
    end
  end

  defp same_account_member?(state, account_id) do
    member_account_ids =
      state.members
      |> Map.keys()
      |> account_ids_by_char_id()

    State.same_account?(member_account_ids, account_id)
  end

  defp account_ids_by_char_id(char_ids) do
    Character
    |> where([c], c.id in ^char_ids)
    |> select([c], {c.id, c.account_id})
    |> Repo.all()
    |> Map.new()
  end

  defp persist_add_member(party_id, character) do
    case Repo.update(Character.changeset(character, %{party_id: party_id})) do
      {:ok, _character} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp put_member(%State{} = state, character) do
    member =
      Member.new(character.id, character.name, character.base_level, true, character.last_map)

    %State{state | members: Map.put(state.members, character.id, member)}
  end

  @doc """
  Removes `char_id` from `party_id`, resets its `characters.party_id` to `0`,
  persists, and broadcasts `{:party_updated, state}`. Removing the leader
  disbands the party instead (design "Leader leaves"), delegating to
  `disband/2`. The leader check is made against live entry state, so it
  cannot be fooled by a stale read racing a concurrent leadership transfer.
  """
  @spec remove_member(non_neg_integer(), non_neg_integer()) ::
          :ok | {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def remove_member(party_id, char_id) do
    case mutate(party_id, &remove_member_reply(char_id, &1)) do
      {:disband, reason} -> disband(party_id, reason)
      other -> other
    end
  end

  defp remove_member_reply(char_id, %State{} = state) do
    cond do
      char_id == state.leader_char_id ->
        {{:disband, "leader_left"}, state}

      Map.has_key?(state.members, char_id) ->
        case persist_remove_member(char_id) do
          :ok ->
            new_state = %State{state | members: Map.delete(state.members, char_id)}
            {{:ok, new_state}, new_state}

          {:error, reason} ->
            {{:error, reason}, state}
        end

      true ->
        {{:error, :not_member}, state}
    end
  end

  defp persist_remove_member(char_id) do
    case Repo.get(Character, char_id) do
      nil ->
        :ok

      character ->
        case Repo.update(Character.changeset(character, %{party_id: 0})) do
          {:ok, _character} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Leader-only kick of `target_char_id`. Works for an offline target (the DB
  write happens regardless of presence); the leader kicking themselves
  disbands the party (design "Kick"). Both the requester and target checks
  are made against live entry state.
  """
  @spec kick(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          :ok | {:ok, State.t()} | {:error, :not_leader | :not_member | :not_found | term()}
  def kick(party_id, requester_char_id, target_char_id) do
    case mutate(party_id, &kick_reply(requester_char_id, target_char_id, &1)) do
      {:disband, reason} -> disband(party_id, reason)
      other -> other
    end
  end

  defp kick_reply(requester_char_id, target_char_id, %State{} = state) do
    if state.leader_char_id != requester_char_id do
      {{:error, :not_leader}, state}
    else
      remove_member_reply(target_char_id, state)
    end
  end

  @doc """
  Leader-only leadership transfer to `target_char_id`, which must be an
  online member on the same map as the current leader (design "Leader
  transfer"). Swaps `leader_char_id`, persists, and broadcasts.
  """
  @spec transfer_leader(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, State.t()}
          | {:error, :not_leader | :not_member | :not_same_map | :not_found | term()}
  def transfer_leader(party_id, requester_char_id, target_char_id) do
    mutate(party_id, &transfer_leader_reply(requester_char_id, target_char_id, &1))
  end

  defp transfer_leader_reply(requester_char_id, target_char_id, %State{} = state) do
    cond do
      state.leader_char_id != requester_char_id ->
        {{:error, :not_leader}, state}

      not Map.has_key?(state.members, target_char_id) ->
        {{:error, :not_member}, state}

      not same_map_as_leader?(state, target_char_id) ->
        {{:error, :not_same_map}, state}

      true ->
        case persist_party(state.party_id, %{leader_char_id: target_char_id}) do
          :ok ->
            new_state = %State{state | leader_char_id: target_char_id}
            {{:ok, new_state}, new_state}

          {:error, reason} ->
            {{:error, reason}, state}
        end
    end
  end

  defp same_map_as_leader?(%State{} = state, target_char_id) do
    leader_member = Map.fetch!(state.members, state.leader_char_id)
    target_member = Map.fetch!(state.members, target_char_id)

    target_member.online and target_member.map_name == leader_member.map_name
  end

  @doc """
  Leader-only toggling of the `exp_share` option. Turning it on is rejected
  with `{:error, :level_range}` when the online members' base-level spread
  exceeds `Config.party_share_level/0` (design "Options").
  """
  @spec set_options(non_neg_integer(), non_neg_integer(), boolean()) ::
          {:ok, State.t()} | {:error, :not_leader | :level_range | :not_found | term()}
  def set_options(party_id, requester_char_id, exp_share) do
    mutate(party_id, &set_options_reply(requester_char_id, exp_share, &1))
  end

  defp set_options_reply(requester_char_id, exp_share, %State{} = state) do
    cond do
      state.leader_char_id != requester_char_id ->
        {{:error, :not_leader}, state}

      exp_share and State.level_spread(state) > Config.party_share_level() ->
        {{:error, :level_range}, state}

      true ->
        case persist_party(state.party_id, %{exp_share: exp_share}) do
          :ok ->
            new_state = %State{state | exp_share: exp_share}
            {{:ok, new_state}, new_state}

          {:error, reason} ->
            {{:error, reason}, state}
        end
    end
  end

  @doc """
  Pushes `char_id`'s new `base_level` into the entry. Recomputes the online
  level spread; if `exp_share` was on and the new spread exceeds
  `Config.party_share_level/0`, flips it off, persists, and broadcasts
  (design "Level/presence tracking"). No-op returning `{:error, :not_found}`
  if the entry isn't running; `{:error, :not_member}` if `char_id` isn't a
  current member (e.g. a stale push racing a leave).
  """
  @spec push_base_level(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def push_base_level(party_id, char_id, base_level) do
    mutate(party_id, fn state ->
      update_member(
        state,
        char_id,
        fn %Member{} = member -> %Member{member | base_level: base_level} end,
        check_spread?: true
      )
    end)
  end

  @doc """
  Pushes `char_id`'s new `map_name` into the entry. Map changes don't affect
  the level-range gate, so `exp_share` is left untouched (design
  "Level/presence tracking").
  """
  @spec push_map_change(non_neg_integer(), non_neg_integer(), String.t()) ::
          {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def push_map_change(party_id, char_id, map_name) do
    mutate(party_id, fn state ->
      update_member(
        state,
        char_id,
        fn %Member{} = member -> %Member{member | map_name: map_name} end,
        check_spread?: false
      )
    end)
  end

  @doc """
  Pushes `char_id`'s `online` flag into the entry. Recomputes the online
  level spread and auto-disables `exp_share` per the same rule as
  `push_base_level/3` -- both login and logout cross this path (design
  "Level/presence tracking"). Never re-enables `exp_share`; re-enabling is a
  manual leader action via `set_options/3`.
  """
  @spec set_online(non_neg_integer(), non_neg_integer(), boolean()) ::
          {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def set_online(party_id, char_id, online?) do
    mutate(party_id, fn state ->
      update_member(
        state,
        char_id,
        fn %Member{} = member -> %Member{member | online: online?} end,
        check_spread?: true
      )
    end)
  end

  defp update_member(%State{} = state, char_id, member_fun, check_spread?: check_spread?) do
    case Map.fetch(state.members, char_id) do
      :error ->
        {{:error, :not_member}, state}

      {:ok, member} ->
        candidate = %State{state | members: Map.put(state.members, char_id, member_fun.(member))}
        candidate = if check_spread?, do: maybe_disable_share(candidate), else: candidate
        finalize_member_update(state, candidate)
    end
  end

  defp maybe_disable_share(%State{exp_share: true} = state) do
    if State.level_spread(state) > Config.party_share_level() do
      %State{state | exp_share: false}
    else
      state
    end
  end

  defp maybe_disable_share(%State{} = state), do: state

  defp finalize_member_update(
         %State{exp_share: exp_share},
         %State{exp_share: exp_share} = new_state
       ) do
    {{:ok, new_state}, new_state}
  end

  defp finalize_member_update(old_state, %State{} = new_state) do
    case persist_party(new_state.party_id, %{exp_share: new_state.exp_share}) do
      :ok -> {{:ok, new_state}, new_state}
      {:error, reason} -> {{:error, reason}, old_state}
    end
  end

  defp persist_party(party_id, changes) do
    case Repo.get(Party, party_id) do
      nil ->
        {:error, :not_found}

      party ->
        case Repo.update(Party.changeset(party, changes)) do
          {:ok, _party} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  defp mutate(party_id, reply_fun) do
    case lookup_pid({:party, party_id}) do
      {:ok, pid} ->
        try do
          case Entry.get_and_update(pid, reply_fun) do
            {:ok, state} = ok ->
              broadcast(party_id, {:party_updated, state})
              ok

            {:error, _reason} = error ->
              error

            other ->
              other
          end
        catch
          :exit, _ -> {:error, :not_found}
        end

      :error ->
        {:error, :not_found}
    end
  end

  defp characters_query(party_id) do
    from c in Character, where: c.party_id == ^party_id
  end

  defp build_state(%Party{} = party, members) do
    %State{
      party_id: party.id,
      name: party.name,
      leader_char_id: party.leader_char_id,
      exp_share: party.exp_share,
      members: Map.new(members, &{&1.char_id, &1})
    }
  end

  defp map_party_error(changeset) do
    case changeset.errors[:name] do
      {_msg, opts} ->
        if Keyword.get(opts, :constraint) == :unique do
          {:error, :name_taken}
        else
          {:error, :invalid_name}
        end

      nil ->
        {:error, changeset}
    end
  end

  defp start_entry(opts, attempts \\ 5) do
    case DynamicSupervisor.start_child(Cluster.owner_supervisor(), {Entry, opts}) do
      {:ok, _pid} ->
        :ok

      :ignore when attempts > 0 ->
        Process.sleep(50)
        start_entry(opts, attempts - 1)

      :ignore ->
        {:error, :already_registered}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp stop_entry(key) do
    case lookup_pid(key) do
      {:ok, pid} ->
        try do
          GenServer.stop(pid, :normal, 1_000)
        catch
          :exit, _ -> :ok
        end

      :error ->
        :ok
    end
  end

  defp lookup_pid(key) do
    case Horde.Registry.lookup(Cluster.registry(), key) do
      [{pid, _value}] -> {:ok, pid}
      [] -> :error
    end
  end

  defp broadcast(party_id, message) do
    Phoenix.PubSub.broadcast(Aesir.PubSub, "party:#{party_id}", message)
  end
end
