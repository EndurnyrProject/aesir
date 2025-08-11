defmodule Aesir.Commons.MementoCluster.Config do
  @moduledoc """
  Configuration module for Memento cluster management.
  Defines table schemas and cluster settings.
  """

  alias Aesir.Commons.InterServer.Schemas.{
    ServerStatus,
    Session,
    OnlineUser,
    CharacterLocation
  }

  @doc """
  Returns the list of tables to be managed by the cluster.
  Each table configuration includes the module and storage type.
  """
  def tables do
    [
      {ServerStatus, :disc_copies},
      {Session, :disc_copies},
      {OnlineUser, :ram_copies},
      {CharacterLocation, :disc_copies}
    ]
  end

  @doc """
  Returns the configured cluster nodes.
  """
  def cluster_nodes do
    Application.get_env(:commons, :memento_cluster, [])
    |> Keyword.get(:nodes, [])
    |> List.wrap()
    |> Enum.filter(&is_atom/1)
  end

  @doc """
  Returns the table load timeout in milliseconds.
  """
  def table_load_timeout do
    Application.get_env(:commons, :memento_cluster, [])
    |> Keyword.get(:table_load_timeout, 60_000)
  end

  @doc """
  Returns whether to auto-cluster on startup.
  """
  def auto_cluster? do
    Application.get_env(:commons, :memento_cluster, [])
    |> Keyword.get(:auto_cluster, true)
  end

  @doc """
  Creates or updates a table with the specified storage type.
  """
  def ensure_table(module, storage_type) do
    table_exists = :mnesia.system_info(:tables) |> Enum.member?(module)

    if table_exists do
      ensure_table_copy(module, storage_type)
    else
      create_table(module, storage_type)
    end
  end

  defp create_table(module, storage_type) do
    opts = [
      {storage_type, [node()]}
    ]

    case Memento.Table.create(module, opts) do
      :ok -> :ok
      {:error, {:already_exists, _}} -> ensure_table_copy(module, storage_type)
      error -> error
    end
  end

  defp ensure_table_copy(module, storage_type) do
    current_node = node()

    # Use Mnesia directly to get table copy info
    nodes =
      case storage_type do
        :disc_copies -> :mnesia.table_info(module, :disc_copies)
        :ram_copies -> :mnesia.table_info(module, :ram_copies)
        :disc_only_copies -> :mnesia.table_info(module, :disc_only_copies)
      end

    case nodes do
      nodes when is_list(nodes) ->
        if current_node in nodes do
          :ok
        else
          add_table_copy(module, storage_type)
        end

      _ ->
        add_table_copy(module, storage_type)
    end
  rescue
    _ -> add_table_copy(module, storage_type)
  end

  defp add_table_copy(module, storage_type) do
    Memento.Table.create_copy(module, node(), storage_type)
  end
end
