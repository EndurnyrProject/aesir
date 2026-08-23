defmodule Aesir.ZoneServer.Guild.Storage.Lock do
  @moduledoc """
  Cluster-wide exclusivity claims for guild storage windows.

  Each claim is an anchored cluster entry, so registration provides mutual
  exclusion and the claim is released when its holder process exits.
  """

  alias Aesir.Commons.Cluster
  alias Aesir.Commons.Cluster.Entry
  alias Horde.Registry, as: HordeRegistry

  @typedoc "The member currently holding a guild's storage open."
  @type holder :: %{char_id: non_neg_integer(), session_pid: pid()}

  @doc "Claims a guild's storage for a character session."
  @spec claim(non_neg_integer(), non_neg_integer(), pid()) ::
          :ok | {:error, :in_use | term()}
  def claim(guild_id, char_id, session_pid) do
    opts = [
      key: {:guild_storage_lock, guild_id},
      value: %{char_id: char_id, session_pid: session_pid},
      anchor: session_pid
    ]

    case DynamicSupervisor.start_child(Cluster.owner_supervisor(), {Entry, opts}) do
      {:ok, _pid} -> :ok
      :ignore -> {:error, :in_use}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Releases a guild's storage when called with its holding session."
  @spec release(non_neg_integer(), pid()) :: :ok
  def release(guild_id, session_pid) do
    case lookup(guild_id) do
      {:ok, owner_pid, %{session_pid: ^session_pid}} -> stop_owner(owner_pid)
      {:ok, _owner_pid, _holder} -> :ok
      :error -> :ok
    end
  end

  @doc "Returns the member currently holding a guild's storage."
  @spec holder(non_neg_integer()) :: {:ok, holder()} | :error
  def holder(guild_id) do
    case lookup(guild_id) do
      {:ok, _owner_pid, holder} -> {:ok, holder}
      :error -> :error
    end
  end

  @doc "Returns whether a session currently holds a guild's storage."
  @spec held_by?(non_neg_integer(), pid()) :: boolean()
  def held_by?(guild_id, session_pid) do
    match?({:ok, %{session_pid: ^session_pid}}, holder(guild_id))
  end

  @doc "Unconditionally drops a guild's storage claim regardless of holder."
  @spec stop(non_neg_integer()) :: :ok
  def stop(guild_id) do
    case lookup(guild_id) do
      {:ok, owner_pid, _holder} -> stop_owner(owner_pid)
      :error -> :ok
    end
  end

  defp lookup(guild_id) do
    case HordeRegistry.lookup(Cluster.registry(), {:guild_storage_lock, guild_id}) do
      [{owner_pid, %{char_id: _char_id, session_pid: _session_pid} = holder}] ->
        {:ok, owner_pid, holder}

      [] ->
        :error
    end
  end

  defp stop_owner(pid) do
    GenServer.stop(pid, :normal, 1_000)
  catch
    :exit, {:noproc, {GenServer, :stop, _args}} -> :ok
  end
end
