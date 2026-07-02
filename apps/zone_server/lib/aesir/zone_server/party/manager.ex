defmodule Aesir.ZoneServer.Party.Manager do
  @moduledoc """
  Facade owning the `{:party, party_id}` Horde entry, mirroring
  `Aesir.Commons.SessionManager`'s shape (design "Runtime state (zone_server)").

  The `parties` table plus `characters.party_id` are the persistence source of
  truth; the entry is the runtime working copy, lazily rebuilt from the DB via
  `ensure_started/1`. This module covers lifecycle only (create/rebuild/lookup/
  disband) -- membership mutations land in a later task.
  """

  import Ecto.Query

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.Cluster.Entry
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Party
  alias Aesir.Repo
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
