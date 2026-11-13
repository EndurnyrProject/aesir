defmodule Aesir.ZoneServer.Guild.Manager do
  @moduledoc """
  Facade owning the `{:guild, guild_id}` Horde entry, mirroring
  `Aesir.ZoneServer.Party.Manager`'s shape.

  The `guilds`/`guild_positions` tables plus `characters.guild_id` +
  `characters.guild_position` are the persistence source of truth; the entry is
  the runtime working copy, lazily rebuilt from the DB via `ensure_started/1`.

  It covers lifecycle (create/rebuild/lookup/disband), membership mutations
  (join/leave/expel), the position/permission layer (edit positions, assign
  members, notice, emblem) and presence tracking (`sync_member/3`).

  Membership, position, skill, level and castle changes are also written to the
  guild's activity log (`Aesir.ZoneServer.Guild.Activity`); the entry carries
  the newest entries so a snapshot never reads them from the database.

  Permission gating replaces party's inline leader check: every gated action
  routes through `Aesir.ZoneServer.Guild.Permissions.can?/3`, and the master
  (position index 0) is always allowed. The emblem blob is written to Postgres
  only; `State` carries just the bumped `emblem_id` version counter.
  """

  require Logger

  import Ecto.Query

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.Cluster.Entry
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildActivityLog
  alias Aesir.Commons.Models.GuildExpulsion
  alias Aesir.Commons.Models.GuildPosition
  alias Aesir.Commons.Models.GuildRelation
  alias Aesir.Repo
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Guild.Activity
  alias Aesir.ZoneServer.Guild.Lifecycle
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.Permissions
  alias Aesir.ZoneServer.Guild.Position
  alias Aesir.ZoneServer.Guild.Progression.Data
  alias Aesir.ZoneServer.Guild.Relation
  alias Aesir.ZoneServer.Guild.Relations
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Guild.Storage.Lock

  @master_index 0
  @newbie_position 19
  @max_position_index 19

  # rAthena `MAX_GUILD_EXP`: the cap of both a member's contribution and the
  # guild's own exp.
  @max_guild_exp 2_147_483_647

  # Membership columns of a character that is in no guild; a member's
  # contribution does not outlive its membership.
  @left_guild %{guild_id: 0, guild_position: 0, guild_exp: 0}

  @doc """
  Creates a guild mastered by `master_character`, persisting it (guild row + 20
  default positions + the master's `characters.guild_id`/`guild_position: 0` +
  the founding activity entry) inside one transaction, and starts its runtime
  entry with the master online.

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
        Character.changeset(master_character, %{
          guild_id: guild.id,
          guild_position: @master_index,
          guild_exp: 0
        })
      end)
      |> Ecto.Multi.insert(:activity, fn %{guild: guild} ->
        GuildActivityLog.changeset(%GuildActivityLog{}, %{
          guild_id: guild.id,
          kind: "created",
          actor: master_character.name
        })
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
          can_notice: position.can_notice,
          can_relations: position.can_relations,
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
  transaction. The guild-row foreign key cascade deletes its storage, then the
  storage claim is stopped. A failed transaction leaves the claim untouched. A
  failed post-commit claim stop is logged but does not suppress the disband
  broadcast or runtime-entry shutdown. It broadcasts
  `{:social, {:guild_disbanded, guild_id, reason}}` on `"guild:\#{guild_id}"`,
  then publishes `{:disbanded, guild_id}` on the global
  `Aesir.ZoneServer.Guild.Lifecycle` topic. Every guild that held a relation
  toward it gets the loss written to its activity log.
  """
  @spec disband(non_neg_integer(), String.t()) :: :ok | {:error, term()}
  def disband(guild_id, reason) do
    case lookup_pid({:guild, guild_id}) do
      {:ok, pid} ->
        # Antagonist rows are one-directional: a peer that declared this
        # guild an antagonist has no row of its own for us to find in
        # `state.relations`, so the incoming side is read from the table
        # before the cascade (triggered inside `disband_reply`) deletes it.
        incoming = relations_toward(guild_id)

        result =
          try do
            Entry.get_and_update(pid, &disband_reply(guild_id, &1))
          catch
            :exit, _ -> {:error, :not_found}
          end

        case result do
          {:ok, state} ->
            stop_storage_claim(guild_id)
            broadcast(guild_id, {:guild_disbanded, guild_id, reason})
            Lifecycle.publish_disbanded(guild_id)
            stop_entry({:guild, guild_id})
            Enum.each(incoming, &log_lost_relation(&1, state.name))
            refresh_relation_peers(Map.keys(state.relations) ++ Enum.map(incoming, &elem(&1, 0)))
            :ok

          {:error, _reason} = error ->
            error
        end

      :error ->
        {:error, :not_found}
    end
  end

  # `{peer_guild_id, kind}` for every relation another guild holds toward
  # `guild_id`.
  defp relations_toward(guild_id) do
    GuildRelation
    |> where([r], r.other_guild_id == ^guild_id)
    |> select([r], {r.guild_id, r.kind})
    |> Repo.all()
  end

  defp log_lost_relation({peer_id, "ally"}, name),
    do: Activity.log(peer_id, :alliance_broken, %{subject: name})

  defp log_lost_relation({peer_id, "antagonist"}, name),
    do: Activity.log(peer_id, :antagonist_removed, %{subject: name})

  # A missing peer entry (`{:error, :not_found}`) is discarded here: the
  # rebuild loads relations from rows on next `ensure_started/1`.
  defp refresh_relation_peers(peer_ids) do
    peer_ids
    |> Enum.uniq()
    |> Enum.each(&put_relations(&1, Relations.load(&1)))
  end

  defp stop_storage_claim(guild_id) do
    Lock.stop(guild_id)
  catch
    :exit, reason ->
      Logger.error("Failed to stop guild storage claim for guild #{guild_id}: #{inspect(reason)}")
      :ok
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
        set: [guild_id: 0, guild_position: 0, guild_exp: 0]
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
  is not at its current member capacity (`State.full?/1`). Persists the member's
  `guild_id` + `guild_position: 19` (Newbie), broadcasts
  `{:social, {:guild_updated, state}}` on success, and leaves the state and
  the character's row untouched on failure. `inviter_char_id` is the member
  whose invite was accepted, named in the activity log.
  """
  @spec add_member(non_neg_integer(), Character.t(), non_neg_integer() | nil) ::
          {:ok, State.t()} | {:error, :guild_full | :not_found | term()}
  def add_member(guild_id, %Character{} = character, inviter_char_id \\ nil) do
    mutate(guild_id, &add_member_reply(character, inviter_char_id, &1))
  end

  defp add_member_reply(character, inviter_char_id, %State{} = state) do
    if State.full?(state) do
      {{:error, :guild_full}, state}
    else
      case persist_member_join(state.guild_id, character) do
        :ok ->
          member = %{
            Member.from_character(character, true, @newbie_position)
            | slot: State.free_slot(state),
              exp: 0
          }

          new_state =
            record(
              %State{state | members: Map.put(state.members, character.id, member)},
              :joined,
              %{subject: character.name, actor: member_name(state, inviter_char_id)}
            )

          {{:ok, new_state}, new_state}

        {:error, reason} ->
          {{:error, reason}, state}
      end
    end
  end

  defp persist_member_join(guild_id, character) do
    changes = %{guild_id: guild_id, guild_position: @newbie_position, guild_exp: 0}

    case Repo.update(Character.changeset(character, changes)) do
      {:ok, _character} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Voluntary leave of `char_id` from `guild_id`: resets its
  `guild_id`/`guild_position` to `0`, persists, and broadcasts
  `{:social, {:guild_updated, state}}`. The master leaving disbands the guild instead (no
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
            new_state =
              record(
                %State{state | members: Map.delete(state.members, char_id)},
                :left,
                %{subject: member_name(state, char_id)}
              )

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
        case Repo.update(Character.changeset(character, @left_guild)) do
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
  broadcasts `{:social, {:guild_updated, state}}`.
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
            new_state =
              record(
                %State{state | members: Map.delete(state.members, target_char_id)},
                :expelled,
                %{
                  subject: member_name(state, target_char_id),
                  actor: member_name(state, requester_char_id)
                }
              )

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
          |> Ecto.Multi.update(:reset, Character.changeset(character, @left_guild))
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
  `{:social, {:guild_emblem_changed, guild_id, emblem_id}}`. Returns the new
  `emblem_id`.
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
  Credits the base EXP member `char_id` was taxed: the full amount to the
  member's own contribution, and that amount scaled by
  `Config.guild_exp_rate/0` to the guild (rAthena `guild_payexp` and the
  `GMI_EXP` branch of `mapif_parse_GuildMemberInfoChange`). Both are capped at
  `MAX_GUILD_EXP`.

  Runs the level-up loop inside the entry (one skill point per level, exp reset
  to progress-toward-next on each level, frozen at the level cap), persists the
  member's contribution and the progression columns, and broadcasts
  `{:social, {:guild_level_up, state}}` only when the level changed.
  Contributions to unknown/dead guilds, or from a character that is no longer a
  member, are dropped; the return is always `:ok` so callers never branch on
  it. Synchronous - EXP producers should invoke it off their own process (e.g.
  `Task.start/1`).
  """
  @spec contribute_exp(non_neg_integer(), non_neg_integer(), pos_integer()) :: :ok
  def contribute_exp(guild_id, char_id, amount) when is_integer(amount) and amount > 0 do
    case lookup_pid({:guild, guild_id}) do
      {:ok, pid} ->
        try do
          case Entry.get_and_update(pid, &contribute_exp_reply(char_id, amount, &1)) do
            {:leveled, state} ->
              broadcast(guild_id, {:guild_level_up, state})
              :ok

            _other ->
              :ok
          end
        catch
          :exit, _ -> :ok
        end

      :error ->
        :ok
    end
  end

  defp contribute_exp_reply(char_id, amount, %State{} = state) do
    case Map.fetch(state.members, char_id) do
      {:ok, %Member{} = member} -> credit_and_persist(member, amount, state)
      :error -> {{:ok, state}, state}
    end
  end

  defp credit_and_persist(%Member{} = member, amount, %State{} = state) do
    member_exp = min(member.exp + amount, @max_guild_exp)
    scaled = div((member_exp - member.exp) * Config.guild_exp_rate(), 100)

    {level, exp, levels_gained} =
      apply_exp(state.level, min(state.exp + scaled, @max_guild_exp), 0)

    credited = %Member{member | exp: member_exp}

    new_state = %State{
      state
      | level: level,
        exp: exp,
        skill_points: state.skill_points + levels_gained,
        members: Map.put(state.members, member.char_id, credited)
    }

    case persist_contribution(new_state, credited) do
      :ok when levels_gained > 0 ->
        new_state = record(new_state, :level_up, %{level: level})
        {{:leveled, new_state}, new_state}

      :ok ->
        {{:ok, new_state}, new_state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp apply_exp(level, exp, levels_gained) do
    case Data.exp_for_next(level) do
      {:ok, needed} when exp >= needed -> apply_exp(level + 1, exp - needed, levels_gained + 1)
      {:ok, _needed} -> {level, exp, levels_gained}
      :max_level -> {level, 0, levels_gained}
    end
  end

  # Rescued so a DB outage during a background contribution drops that
  # contribution (old state kept) instead of crashing the guild entry.
  defp persist_contribution(%State{} = state, %Member{} = member) do
    progression = %{level: state.level, exp: state.exp, skill_points: state.skill_points}

    result =
      Repo.transaction(fn ->
        Repo.update_all(from(c in Character, where: c.id == ^member.char_id),
          set: [guild_exp: member.exp]
        )

        with {:error, reason} <- persist_guild(state.guild_id, progression) do
          Repo.rollback(reason)
        end
      end)

    with {:ok, :ok} <- result, do: :ok
  rescue
    error -> {:error, error}
  end

  @doc """
  Master-only guild skill point allocation.

  Validates against the imported guild skill tree (`Progression.Data`): the
  caller must be the guild master, a point must be available, the skill must be
  a tree skill below its max level with all prerequisite levels met. Persists
  `skill_points`/`learned_skills` and broadcasts both
  `{:social, {:guild_updated, state}}` and `{:social, {:guild_skill_update,
  state}}` (the latter drives master-aura re-application).
  """
  @spec allocate_skill_point(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, State.t()}
          | {:error,
             :not_master
             | :no_skill_points
             | :prerequisite_not_met
             | :max_level_reached
             | :unknown_skill
             | :not_found
             | term()}
  def allocate_skill_point(guild_id, char_id, skill_id) do
    case mutate(guild_id, &allocate_reply(char_id, skill_id, &1)) do
      {:ok, state} = ok ->
        broadcast(guild_id, {:guild_skill_update, state})
        ok

      error ->
        error
    end
  end

  defp allocate_reply(char_id, skill_id, %State{} = state) do
    case validate_allocation(char_id, skill_id, state) do
      :ok -> learn_and_persist(skill_id, state)
      {:error, reason} -> {{:error, reason}, state}
    end
  end

  defp learn_and_persist(skill_id, %State{} = state) do
    new_level = State.skill_level(state, skill_id) + 1

    new_state = %State{
      state
      | skill_points: state.skill_points - 1,
        learned_skills: Map.put(state.learned_skills, skill_id, new_level)
    }

    case persist_learned_skills(new_state) do
      :ok ->
        new_state =
          record(new_state, :skill_learned, %{
            actor: member_name(state, state.master_char_id),
            skill_id: skill_id,
            level: new_level
          })

        {{:ok, new_state}, new_state}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp validate_allocation(char_id, skill_id, %State{} = state) do
    if state.master_char_id == char_id do
      case Data.skill_entry(skill_id) do
        {:ok, entry} -> validate_tree_entry(entry, skill_id, state)
        :error -> {:error, :unknown_skill}
      end
    else
      {:error, :not_master}
    end
  end

  defp validate_tree_entry(entry, skill_id, %State{} = state) do
    cond do
      state.skill_points < 1 ->
        {:error, :no_skill_points}

      State.skill_level(state, skill_id) >= entry.max_level ->
        {:error, :max_level_reached}

      not Enum.all?(entry.prerequisites, fn {req_id, req_level} ->
        State.skill_level(state, req_id) >= req_level
      end) ->
        {:error, :prerequisite_not_met}

      true ->
        :ok
    end
  end

  defp persist_learned_skills(%State{} = state) do
    persist_guild(state.guild_id, %{
      skill_points: state.skill_points,
      learned_skills:
        Map.new(state.learned_skills, fn {id, level} -> {Integer.to_string(id), level} end)
    })
  rescue
    error -> {:error, error}
  end

  @doc """
  `:notice`-gated guild-notice update. Persists `notice_subject`/`notice_body`
  together with the editor's name and the edit time, updates the entry, and
  broadcasts `{:social, {:guild_updated, state}}`.
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
      author = member_name(state, char_id)
      posted_at = DateTime.truncate(DateTime.utc_now(), :second)

      changes = %{
        notice_subject: subject,
        notice_body: body,
        notice_author: author,
        notice_posted_at: posted_at
      }

      case persist_guild(state.guild_id, changes) do
        :ok ->
          new_state = %State{
            state
            | notice: %{subject: subject, body: body},
              notice_author: author,
              notice_posted_at: DateTime.to_unix(posted_at)
          }

          {{:ok, new_state}, new_state}

        {:error, reason} ->
          {{:error, reason}, state}
      end
    else
      {{:error, :no_permission}, state}
    end
  end

  @doc """
  Position-editing (`:positions`) update of one non-zero slot's `name` and
  permission flags. Index 0 (the master slot) is protected and returns
  `{:error, :no_permission}`; an index outside `0..19` returns
  `{:error, :invalid_position}`. `tax` (the position's guild EXP tax, clamped
  to `Config.guild_exp_limit/0`), `can_storage`, `can_notice` and
  `can_relations` are optional: absent or `nil` leaves the stored value
  unchanged. Broadcasts `{:social, {:guild_updated, state}}`.
  """
  @spec edit_position(non_neg_integer(), non_neg_integer(), %{
          :index => non_neg_integer(),
          :name => String.t(),
          :can_invite => boolean(),
          :can_expel => boolean(),
          optional(:tax) => non_neg_integer() | nil,
          optional(:can_storage) => boolean() | nil,
          optional(:can_notice) => boolean() | nil,
          optional(:can_relations) => boolean() | nil
        }) ::
          {:ok, State.t()} | {:error, :no_permission | :invalid_position | :not_found | term()}
  def edit_position(
        guild_id,
        char_id,
        %{index: index, name: _name, can_invite: _can_invite, can_expel: _can_expel} = changes
      ) do
    mutate(guild_id, &edit_position_reply(char_id, index, changes, &1))
  end

  defp edit_position_reply(char_id, index, changes, %State{} = state) do
    cond do
      not Permissions.can?(state, char_id, :positions) ->
        {{:error, :no_permission}, state}

      index == @master_index ->
        {{:error, :no_permission}, state}

      index < 0 or index > @max_position_index ->
        {{:error, :invalid_position}, state}

      true ->
        %Position{} = existing = Map.get(state.positions, index, %Position{index: index})
        fields = position_fields(existing, changes)

        case persist_position(state.guild_id, index, fields) do
          :ok ->
            updated = struct!(existing, fields)
            new_state = %State{state | positions: Map.put(state.positions, index, updated)}
            {{:ok, new_state}, new_state}

          {:error, reason} ->
            {{:error, reason}, state}
        end
    end
  end

  # The position's editable fields after `changes`: the required ones are
  # always replaced, the optional ones only when the request carries a value.
  defp position_fields(%Position{} = existing, changes) do
    optional =
      changes
      |> Map.take([:tax, :can_storage, :can_notice, :can_relations])
      |> Map.reject(fn {_field, value} -> is_nil(value) end)
      |> Map.replace_lazy(:tax, &min(&1, Config.guild_exp_limit()))

    existing
    |> Map.take([:tax, :can_storage, :can_notice, :can_relations])
    |> Map.merge(optional)
    |> Map.merge(Map.take(changes, [:name, :can_invite, :can_expel]))
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
  `guild_position`, updates the entry, and broadcasts
  `{:social, {:guild_updated, state}}`.
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

            new_state =
              record_position_change(
                %State{state | members: Map.put(state.members, target_char_id, updated)},
                member,
                index,
                requester_char_id
              )

            {{:ok, new_state}, new_state}

          {:error, reason} ->
            {{:error, reason}, state}
        end
    end
  end

  # Re-assigning a member to the position it already holds is not a change.
  defp record_position_change(state, %Member{position_index: index}, index, _requester_char_id),
    do: state

  defp record_position_change(%State{} = state, %Member{} = member, index, requester_char_id) do
    record(state, :position_changed, %{
      subject: member.name,
      actor: member_name(state, requester_char_id),
      detail: position_name(state, index)
    })
  end

  defp position_name(%State{positions: positions}, index) do
    case Map.get(positions, index) do
      %Position{name: name} -> name
      nil -> ""
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
  Replaces one member's presence snapshot in the live guild entry. The stored
  `position_index`, `slot` and `exp` are always preserved (they are
  authoritative in the guild entry, never in the session presence projection),
  so only the presence fields from `member` are applied. `last_seen` is stamped
  when the member comes online, as `characters.last_login` is when the
  character is selected, and kept otherwise. Changed snapshots emit
  `{:social, {:guild_member_updated, guild_id, member}}`; identical snapshots
  are a no-op.
  A snapshot whose `char_id` differs from the member key is rejected with
  `{:error, :not_member}`.
  """
  @spec sync_member(non_neg_integer(), non_neg_integer(), Member.t()) ::
          {:ok, State.t()} | {:error, :not_member | :not_found | term()}
  def sync_member(guild_id, char_id, %Member{} = member) do
    case lookup_pid({:guild, guild_id}) do
      {:ok, pid} ->
        try do
          case Entry.get_and_update(pid, &replace_member_reply(&1, char_id, member)) do
            {:ok, :updated, merged, state} ->
              broadcast(guild_id, {:guild_member_updated, guild_id, merged})
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

  defp replace_member(%State{} = state, char_id, %Member{} = member) do
    case Map.fetch(state.members, char_id) do
      :error ->
        {{:error, :not_member}, state}

      {:ok, %Member{} = old_member} ->
        merged = %Member{
          member
          | position_index: old_member.position_index,
            slot: old_member.slot,
            exp: old_member.exp,
            last_seen: last_seen(old_member, member)
        }

        if merged == old_member do
          {{:ok, :unchanged, state}, state}
        else
          new_state = %State{state | members: Map.put(state.members, char_id, merged)}
          {{:ok, :updated, merged, new_state}, new_state}
        end
    end
  end

  defp last_seen(%Member{online: false}, %Member{online: true}), do: System.os_time(:second)
  defp last_seen(%Member{last_seen: last_seen}, %Member{}), do: last_seen

  @doc """
  Replaces the live entry's relation map, e.g. after
  `Aesir.ZoneServer.Guild.Relations` commits a write touching `guild_id`, and
  re-reads its recent activity, since a relation change is logged by the
  transaction that made it. Broadcasts `{:social, {:guild_updated, state}}` on
  `"guild:\#{guild_id}"`.
  """
  @spec put_relations(non_neg_integer(), %{pos_integer() => Relation.t()}) ::
          :ok | {:error, :not_found}
  def put_relations(guild_id, relations) do
    case lookup_pid({:guild, guild_id}) do
      {:ok, pid} ->
        try do
          {:ok, state} = Entry.update(pid, &replace_relations(&1, relations))
          broadcast(guild_id, {:guild_updated, state})
          :ok
        catch
          :exit, _ -> {:error, :not_found}
        end

      :error ->
        {:error, :not_found}
    end
  end

  defp replace_relations(%State{} = state, relations) do
    %State{state | relations: relations, activity: Activity.recent(state.guild_id)}
  end

  @doc """
  Writes one entry to `guild_id`'s activity log for something that happened
  outside the entry (a castle changing hands). A live entry also carries it and
  broadcasts `{:social, {:guild_updated, state}}`, so members get a fresh
  `GuildInfo`; a guild without a live entry only gets the row.
  """
  @spec record_activity(non_neg_integer(), Activity.kind(), map()) :: :ok
  def record_activity(guild_id, kind, attrs) do
    case lookup_pid({:guild, guild_id}) do
      {:ok, pid} ->
        try do
          {:ok, state} = Entry.update(pid, &record(&1, kind, attrs))
          broadcast(guild_id, {:guild_updated, state})
          :ok
        catch
          :exit, _ -> :ok
        end

      :error ->
        _ = Activity.log(guild_id, kind, attrs)
        :ok
    end
  end

  # An activity entry is never worth failing the change it describes: a row
  # that cannot be written is logged and skipped.
  defp record(%State{} = state, kind, attrs) do
    case Activity.log(state.guild_id, kind, attrs) do
      {:ok, entry} ->
        %State{state | activity: Activity.prepend(state.activity, entry)}

      {:error, reason} ->
        Logger.warning(
          "Guild #{state.guild_id} activity #{kind} not recorded: #{inspect(reason)}"
        )

        state
    end
  end

  defp member_name(%State{members: members}, char_id) do
    case Map.get(members, char_id) do
      %Member{name: name} -> name
      nil -> ""
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
      notice_author: guild.notice_author || "",
      notice_posted_at: unix_seconds(guild.notice_posted_at),
      positions: positions,
      members: numbered_members(members),
      level: guild.level,
      exp: guild.exp,
      skill_points: guild.skill_points,
      learned_skills: decode_learned_skills(guild.learned_skills),
      relations: Relations.load(guild.id),
      activity: Activity.recent(guild.id)
    }
  end

  defp unix_seconds(nil), do: 0
  defp unix_seconds(%DateTime{} = at), do: DateTime.to_unix(at)

  defp numbered_members(members) do
    members
    |> Enum.sort_by(&{&1.position_index, &1.char_id})
    |> Enum.with_index()
    |> Map.new(fn {member, slot} -> {member.char_id, %{member | slot: slot}} end)
  end

  # jsonb map keys come back as strings; runtime state keys skills by integer id.
  defp decode_learned_skills(skills) do
    Map.new(skills, fn
      {key, level} when is_binary(key) -> {String.to_integer(key), level}
      {key, level} -> {key, level}
    end)
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
    Phoenix.PubSub.broadcast(Aesir.PubSub, "guild:#{guild_id}", {:social, message})
  end
end
