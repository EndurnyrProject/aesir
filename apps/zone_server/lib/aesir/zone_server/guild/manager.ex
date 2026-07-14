defmodule Aesir.ZoneServer.Guild.Manager do
  @moduledoc """
  Facade owning the `{:guild, guild_id}` Horde entry, mirroring
  `Aesir.ZoneServer.Party.Manager`'s shape.

  The `guilds`/`guild_positions` tables plus `characters.guild_id` +
  `characters.guild_position` are the persistence source of truth; the entry is
  the runtime working copy, lazily rebuilt from the DB via `ensure_started/1`.

  It covers lifecycle (create/rebuild/lookup/disband), membership mutations
  (join/leave/expel), the position/permission layer (edit positions, assign
  members, notice, emblem) and presence tracking (`sync_member/3`,
  `set_online/3`, `push_base_level/3`, `push_map_change/3`).

  Permission gating replaces party's inline leader check: every gated action
  routes through `Aesir.ZoneServer.Guild.Permissions.can?/3`, and the master
  (position index 0) is always allowed. The emblem blob is written to Postgres
  only; `State` carries just the bumped `emblem_id` version counter.
  """

  import Ecto.Query

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.Cluster.Entry
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildExpulsion
  alias Aesir.Commons.Models.GuildPosition
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Permissions
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.State

  @master_index 0
  @newbie_position 19
  @max_position_index 19

  @doc """
  Creates a guild mastered by `master_character`, persisting it (guild row + 20
  default positions + the master's `characters.guild_id`/`guild_position: 0`)
  inside one transaction, and starts its runtime entry with the master online.

  Does not touch inventory: the Emperium is sequenced by the caller's session.
  A duplicate name rolls the whole transaction back and returns
  `{:error, :name_taken}` with no rows written.
  """
  @spec create(String.t(), Character.t()) ::
          {:ok, State.t()} | {:error, :name_taken | :invalid_name | term()}
  def create(name, %Character{} = master_character) do
    positions = Position.defaults()

    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.insert(
        :guild,
        GuildModel.changeset(%GuildModel{}, %{name: name, master_char_id: master_character.id})
      )
      |> Ecto.Multi.run(:positions, fn repo, %{guild: guild} ->
        insert_default_positions(repo, guild.id, positions)
      end)
      |> Ecto.Multi.update(:master, fn %{guild: guild} ->
        Character.changeset(master_character, %{guild_id: guild.id, guild_position: @master_index})
      end)

    case Repo.transaction(multi) do
      {:ok, %{guild: guild}} ->
        master_member = Member.from_character(master_character, true, @master_index)
        finish_create(guild, [master_member], position_map(positions))

      {:error, :guild, changeset, _changes} ->
        map_guild_error(changeset)

      {:error, _step, reason, _changes} ->
        {:error, reason}
    end
  end

  defp insert_default_positions(repo, guild_id, positions) do
    rows =
      Enum.map(positions, fn %Position{} = position ->
        %{
          guild_id: guild_id,
          index: position.index,
          name: position.name,
          can_invite: position.can_invite,
          can_expel: position.can_expel,
          can_storage: position.can_storage,
          tax: position.tax
        }
      end)

    {count, _} = repo.insert_all(GuildPosition, rows)
    {:ok, count}
  end

  defp position_map(positions), do: Map.new(positions, &{&1.index, &1})

  defp finish_create(guild, members, positions) do
    state = build_state(guild, members, positions)

    case start_entry(key: {:guild, guild.id}, value: state) do
      :ok -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Ensures `{:guild, guild_id}` has a live entry, rebuilding it from the DB
  (guild row + its positions + every `Character` row where `guild_id` matches,
  all offline until each member's session pushes presence) when none is
  running. Idempotent -- returns the existing state if one already runs.
  """
  @spec ensure_started(non_neg_integer()) :: {:ok, State.t()} | {:error, :not_found | term()}
  def ensure_started(guild_id) do
    case get(guild_id) do
      {:ok, state} -> {:ok, state}
      {:error, :not_found} -> rebuild_or_fetch(guild_id)
    end
  end

  defp rebuild_or_fetch(guild_id) do
    case rebuild(guild_id) do
      {:error, :already_registered} -> get(guild_id)
      other -> other
    end
  end

  defp rebuild(guild_id) do
    case Repo.get(GuildModel, guild_id) do
      nil ->
        {:error, :not_found}

      guild ->
        positions = load_positions(guild_id)

        members =
          guild_id
          |> characters_query()
          |> Repo.all()
          |> Enum.map(&member_from_character/1)

        finish_create(guild, members, positions)
    end
  end

  @doc """
  Reads the live entry for `guild_id` without rebuilding it.
  """
  @spec get(non_neg_integer()) :: {:ok, State.t()} | {:error, :not_found}
  def get(guild_id) do
    case Horde.Registry.lookup(Cluster.registry(), {:guild, guild_id}) do
      [{_pid, %State{} = state}] -> {:ok, state}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Disbands a guild: resets `guild_id`/`guild_position` to `0` for every member
  row and deletes the guild's positions, expulsions and row in one DB
  transaction (explicit cascade, not a DB constraint), broadcasts
  `{:guild_disbanded, guild_id, reason}` on `"guild:\#{guild_id}"`, and stops
  the entry.
  """
  @spec disband(non_neg_integer(), String.t()) :: :ok | {:error, term()}
  def disband(guild_id, reason) do
    case lookup_pid({:guild, guild_id}) do
      {:ok, pid} ->
        try do
          case Entry.get_and_update(pid, &disband_reply(guild_id, &1)) do
            {:ok, _state} ->
              broadcast(guild_id, {:guild_disbanded, guild_id, reason})
              stop_entry({:guild, guild_id})
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

  defp disband_reply(guild_id, state) do
    case delete_guild_cascade(guild_id) do
      :ok -> {{:ok, state}, state}
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp delete_guild_cascade(guild_id) do
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.update_all(
        :reset_members,
        characters_query(guild_id),
        set: [guild_id: 0, guild_position: 0]
      )
      |> Ecto.Multi.delete_all(:positions, positions_query(guild_id))
      |> Ecto.Multi.delete_all(:expulsions, expulsions_query(guild_id))
      |> Ecto.Multi.run(:guild, fn repo, _changes ->
        case repo.get(GuildModel, guild_id) do
          nil -> {:error, :not_found}
          guild -> repo.delete(guild)
        end
      end)

    case Repo.transaction(multi) do
      {:ok, _changes} -> :ok
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  @doc """
  Adds `character` to `guild_id`, re-validating inside the entry that the guild
  is not at the fixed cap of 16 (`State.full?/1`). Persists the member's
  `guild_id` + `guild_position: 19` (Newbie), broadcasts `{:guild_updated,
  state}` on success, and leaves the state and the character's row untouched on
  failure.
  """
  @spec add_member(non_neg_integer(), Character.t()) ::
          {:ok, State.t()} | {:error, :guild_full | :not_found | term()}
  def add_member(guild_id, %Character{} = character) do
    mutate(guild_id, &add_member_reply(character, &1))
  end

  defp add_member_reply(character, %State{} = state) do
    if State.full?(state) do
      {{:error, :guild_full}, state}
    else
      case persist_member_join(state.guild_id, character) do
        :ok ->
          member = Member.from_character(character, true, @newbie_position)
          new_state = %State{state | members: Map.put(state.members, character.id, member)}
          {{:ok, new_state}, new_state}

        {:error, reason} ->
          {{:error, reason}, state}
      end
    end
  end

  defp persist_member_join(guild_id, character) do
    changes = %{guild_id: guild_id, guild_position: @newbie_position}

    case Repo.update(Character.changeset(character, changes)) do
      {:ok, _character} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Voluntary leave of `char_id` from `guild_id`: resets its
  `guild_id`/`guild_position` to `0`, persists, and broadcasts
  `{:guild_updated, state}`. The master leaving disbands the guild instead (no
  transfer this phase), delegating to `disband/2`. The master check runs
  against live entry state.
  """
  @spec remove_member(non_neg_integer(), non_neg_integer()) ::
          :ok | {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def remove_member(guild_id, char_id) do
    case mutate(guild_id, &remove_member_reply(char_id, &1)) do
      {:disband, reason} -> disband(guild_id, reason)
      other -> other
    end
  end

  defp remove_member_reply(char_id, %State{} = state) do
    cond do
      char_id == state.master_char_id ->
        {{:disband, "master_left"}, state}

      Map.has_key?(state.members, char_id) ->
        case persist_member_reset(char_id) do
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

  defp persist_member_reset(char_id) do
    case Repo.get(Character, char_id) do
      nil ->
        :ok

      character ->
        case Repo.update(Character.changeset(character, %{guild_id: 0, guild_position: 0})) do
          {:ok, _character} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Expels `target_char_id` from `guild_id` on behalf of `requester_char_id`.
  Requires the requester's position to grant the `:expel` permission
  (`{:error, :no_permission}` otherwise) and refuses to target the master
  (`{:error, :cannot_target_master}`). On success it resets the target's row
  and writes exactly one `GuildExpulsion` row in one transaction, then
  broadcasts `{:guild_updated, state}`.
  """
  @spec expel(non_neg_integer(), non_neg_integer(), non_neg_integer(), String.t()) ::
          {:ok, State.t()}
          | {:error, :no_permission | :cannot_target_master | :not_member | :not_found | term()}
  def expel(guild_id, requester_char_id, target_char_id, reason) do
    mutate(guild_id, &expel_reply(requester_char_id, target_char_id, reason, &1))
  end

  defp expel_reply(requester_char_id, target_char_id, reason, %State{} = state) do
    cond do
      not Permissions.can?(state, requester_char_id, :expel) ->
        {{:error, :no_permission}, state}

      target_char_id == state.master_char_id ->
        {{:error, :cannot_target_master}, state}

      not Map.has_key?(state.members, target_char_id) ->
        {{:error, :not_member}, state}

      true ->
        case persist_expel(state.guild_id, target_char_id, reason) do
          :ok ->
            new_state = %State{state | members: Map.delete(state.members, target_char_id)}
            {{:ok, new_state}, new_state}

          {:error, error} ->
            {{:error, error}, state}
        end
    end
  end

  defp persist_expel(guild_id, target_char_id, reason) do
    case Repo.get(Character, target_char_id) do
      nil ->
        {:error, :not_found}

      character ->
        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.update(
            :reset,
            Character.changeset(character, %{guild_id: 0, guild_position: 0})
          )
          |> Ecto.Multi.insert(
            :expulsion,
            GuildExpulsion.changeset(%GuildExpulsion{}, %{
              guild_id: guild_id,
              char_id: character.id,
              name: character.name,
              account_id: character.account_id,
              reason: reason
            })
          )

        case Repo.transaction(multi) do
          {:ok, _changes} -> :ok
          {:error, _step, error, _changes} -> {:error, error}
        end
    end
  end

  @doc """
  Master-only emblem change: stores `data` as the guild's `emblem_data` and
  bumps `emblem_id` by one in Postgres, updates the entry's `emblem_id` version
  counter (the blob is not held in `State`), and broadcasts
  `{:guild_emblem_changed, guild_id, emblem_id}`. Returns the new `emblem_id`.
  """
  @spec change_emblem(non_neg_integer(), non_neg_integer(), binary()) ::
          {:ok, non_neg_integer()} | {:error, :no_permission | :not_found | term()}
  def change_emblem(guild_id, char_id, data) do
    case lookup_pid({:guild, guild_id}) do
      {:ok, pid} ->
        try do
          case Entry.get_and_update(pid, &change_emblem_reply(char_id, data, &1)) do
            {:ok, emblem_id} ->
              broadcast(guild_id, {:guild_emblem_changed, guild_id, emblem_id})
              {:ok, emblem_id}

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

  defp change_emblem_reply(char_id, data, %State{} = state) do
    if Permissions.can?(state, char_id, :emblem) do
      emblem_id = state.emblem_id + 1

      case persist_guild(state.guild_id, %{emblem_data: data, emblem_id: emblem_id}) do
        :ok ->
          new_state = %State{state | emblem_id: emblem_id}
          {{:ok, emblem_id}, new_state}

        {:error, reason} ->
          {{:error, reason}, state}
      end
    else
      {{:error, :no_permission}, state}
    end
  end

  @doc """
  Master-only (`:notice`) guild-notice update. Persists `notice_subject`/
  `notice_body`, updates the entry's `notice`, and broadcasts
  `{:guild_updated, state}`.
  """
  @spec set_notice(non_neg_integer(), non_neg_integer(), %{
          subject: String.t(),
          body: String.t()
        }) :: {:ok, State.t()} | {:error, :no_permission | :not_found | term()}
  def set_notice(guild_id, char_id, %{subject: subject, body: body}) do
    mutate(guild_id, &set_notice_reply(char_id, subject, body, &1))
  end

  defp set_notice_reply(char_id, subject, body, %State{} = state) do
    if Permissions.can?(state, char_id, :notice) do
      case persist_guild(state.guild_id, %{notice_subject: subject, notice_body: body}) do
        :ok ->
          new_state = %State{state | notice: %{subject: subject, body: body}}
          {{:ok, new_state}, new_state}

        {:error, reason} ->
          {{:error, reason}, state}
      end
    else
      {{:error, :no_permission}, state}
    end
  end

  @doc """
  Position-editing (`:positions`) update of one non-zero slot's `name`,
  `can_invite` and `can_expel`. Index 0 (the master slot) is protected and
  returns `{:error, :no_permission}`; an index outside `0..19` returns
  `{:error, :invalid_position}`. The inert `can_storage`/`tax` fields are
  preserved. Broadcasts `{:guild_updated, state}`.
  """
  @spec edit_position(non_neg_integer(), non_neg_integer(), %{
          index: non_neg_integer(),
          name: String.t(),
          can_invite: boolean(),
          can_expel: boolean()
        }) ::
          {:ok, State.t()} | {:error, :no_permission | :invalid_position | :not_found | term()}
  def edit_position(guild_id, char_id, %{
        index: index,
        name: name,
        can_invite: can_invite,
        can_expel: can_expel
      }) do
    mutate(guild_id, &edit_position_reply(char_id, index, name, can_invite, can_expel, &1))
  end

  defp edit_position_reply(char_id, index, name, can_invite, can_expel, %State{} = state) do
    cond do
      not Permissions.can?(state, char_id, :positions) ->
        {{:error, :no_permission}, state}

      index == @master_index ->
        {{:error, :no_permission}, state}

      index < 0 or index > @max_position_index ->
        {{:error, :invalid_position}, state}

      true ->
        changes = %{name: name, can_invite: can_invite, can_expel: can_expel}

        case persist_position(state.guild_id, index, changes) do
          :ok ->
            %Position{} = existing = Map.get(state.positions, index, %Position{index: index})

            updated = %Position{
              existing
              | name: name,
                can_invite: can_invite,
                can_expel: can_expel
            }

            new_state = %State{state | positions: Map.put(state.positions, index, updated)}
            {{:ok, new_state}, new_state}

          {:error, reason} ->
            {{:error, reason}, state}
        end
    end
  end

  defp persist_position(guild_id, index, changes) do
    case Repo.get_by(GuildPosition, guild_id: guild_id, index: index) do
      nil ->
        {:error, :not_found}

      position ->
        case Repo.update(GuildPosition.changeset(position, changes)) do
          {:ok, _position} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Master-only (`:assign`) assignment of `target_char_id` to position `index`.
  Rejects an index outside `0..19` with `{:error, :invalid_position}` and a
  non-member target with `{:error, :not_member}`. Persists the target's
  `guild_position`, updates the entry, and broadcasts `{:guild_updated, state}`.
  """
  @spec assign_member_position(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          {:ok, State.t()}
          | {:error, :no_permission | :invalid_position | :not_member | :not_found | term()}
  def assign_member_position(guild_id, requester_char_id, target_char_id, index) do
    mutate(guild_id, &assign_member_position_reply(requester_char_id, target_char_id, index, &1))
  end

  defp assign_member_position_reply(requester_char_id, target_char_id, index, %State{} = state) do
    cond do
      not Permissions.can?(state, requester_char_id, :assign) ->
        {{:error, :no_permission}, state}

      index < 0 or index > @max_position_index ->
        {{:error, :invalid_position}, state}

      not Map.has_key?(state.members, target_char_id) ->
        {{:error, :not_member}, state}

      true ->
        case persist_member_position(target_char_id, index) do
          :ok ->
            %Member{} = member = Map.fetch!(state.members, target_char_id)
            updated = %Member{member | position_index: index}
            new_state = %State{state | members: Map.put(state.members, target_char_id, updated)}
            {{:ok, new_state}, new_state}

          {:error, reason} ->
            {{:error, reason}, state}
        end
    end
  end

  defp persist_member_position(char_id, index) do
    case Repo.get(Character, char_id) do
      nil ->
        {:error, :not_found}

      character ->
        case Repo.update(Character.changeset(character, %{guild_position: index})) do
          {:ok, _character} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  @doc """
  Pushes `char_id`'s new `base_level` into the entry, broadcasting
  `{:guild_updated, state}`. `{:error, :not_member}` if `char_id` isn't a
  current member; `{:error, :not_found}` if the entry isn't running.
  """
  @spec push_base_level(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def push_base_level(guild_id, char_id, base_level) do
    mutate(guild_id, fn state ->
      update_member(state, char_id, fn %Member{} = member ->
        %Member{member | base_level: base_level}
      end)
    end)
  end

  @doc """
  Pushes `char_id`'s new `map_name` into the entry, broadcasting
  `{:guild_updated, state}`.
  """
  @spec push_map_change(non_neg_integer(), non_neg_integer(), String.t()) ::
          {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def push_map_change(guild_id, char_id, map_name) do
    mutate(guild_id, fn state ->
      update_member(state, char_id, fn %Member{} = member ->
        %Member{member | map_name: map_name}
      end)
    end)
  end

  @doc """
  Pushes `char_id`'s `online` flag into the entry -- both login and logout
  cross this path -- broadcasting `{:guild_updated, state}`.
  """
  @spec set_online(non_neg_integer(), non_neg_integer(), boolean()) ::
          {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def set_online(guild_id, char_id, online?) do
    mutate(guild_id, fn state ->
      update_member(state, char_id, fn %Member{} = member ->
        %Member{member | online: online?}
      end)
    end)
  end

  @doc """
  Replaces one member's complete runtime snapshot in the live guild entry.
  Changed snapshots emit `{:guild_member_updated, guild_id, member}`; identical
  snapshots are a no-op. A snapshot whose `char_id` differs from the member key
  is rejected with `{:error, :not_member}`.
  """
  @spec sync_member(non_neg_integer(), non_neg_integer(), Member.t()) ::
          {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def sync_member(guild_id, char_id, %Member{} = member) do
    case lookup_pid({:guild, guild_id}) do
      {:ok, pid} ->
        try do
          case Entry.get_and_update(pid, &replace_member_reply(&1, char_id, member)) do
            {:ok, :updated, state} ->
              broadcast(guild_id, {:guild_member_updated, guild_id, member})
              {:ok, state}

            {:ok, :unchanged, state} ->
              {:ok, state}

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

  defp replace_member_reply(%State{} = state, char_id, member) do
    if member.char_id == char_id do
      replace_member(state, char_id, member)
    else
      {{:error, :not_member}, state}
    end
  end

  defp replace_member(%State{} = state, char_id, member) do
    case Map.fetch(state.members, char_id) do
      :error ->
        {{:error, :not_member}, state}

      {:ok, ^member} ->
        {{:ok, :unchanged, state}, state}

      {:ok, _old_member} ->
        new_state = %State{state | members: Map.put(state.members, char_id, member)}
        {{:ok, :updated, new_state}, new_state}
    end
  end

  defp update_member(%State{} = state, char_id, member_fun) do
    case Map.fetch(state.members, char_id) do
      :error ->
        {{:error, :not_member}, state}

      {:ok, member} ->
        new_state = %State{state | members: Map.put(state.members, char_id, member_fun.(member))}
        {{:ok, new_state}, new_state}
    end
  end

  defp persist_guild(guild_id, changes) do
    case Repo.get(GuildModel, guild_id) do
      nil ->
        {:error, :not_found}

      guild ->
        case Repo.update(GuildModel.changeset(guild, changes)) do
          {:ok, _guild} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  defp mutate(guild_id, reply_fun) do
    case lookup_pid({:guild, guild_id}) do
      {:ok, pid} ->
        try do
          case Entry.get_and_update(pid, reply_fun) do
            {:ok, state} = ok ->
              broadcast(guild_id, {:guild_updated, state})
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

  defp characters_query(guild_id) do
    from c in Character, where: c.guild_id == ^guild_id
  end

  defp positions_query(guild_id) do
    from p in GuildPosition, where: p.guild_id == ^guild_id
  end

  defp expulsions_query(guild_id) do
    from e in GuildExpulsion, where: e.guild_id == ^guild_id
  end

  defp load_positions(guild_id) do
    guild_id
    |> positions_query()
    |> Repo.all()
    |> Map.new(fn model -> {model.index, Position.from_model(model)} end)
  end

  defp member_from_character(%Character{} = character) do
    Member.from_character(character, false, character.guild_position)
  end

  defp build_state(%GuildModel{} = guild, members, positions) do
    %State{
      guild_id: guild.id,
      name: guild.name,
      master_char_id: guild.master_char_id,
      emblem_id: guild.emblem_id,
      notice: %{subject: guild.notice_subject || "", body: guild.notice_body || ""},
      positions: positions,
      members: Map.new(members, &{&1.char_id, &1})
    }
  end

  defp map_guild_error(changeset) do
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

  defp broadcast(guild_id, message) do
    Phoenix.PubSub.broadcast(Aesir.PubSub, "guild:#{guild_id}", message)
  end
end
