defmodule Aesir.Commons.MementoTestHelper do
  @moduledoc """
  Helper module for managing Memento tables in test environment.
  Provides utilities to recreate tables with updated schemas.
  """

  alias Aesir.Commons.InterServer.Schemas.CharacterLocation
  alias Aesir.Commons.InterServer.Schemas.OnlineUser
  alias Aesir.Commons.InterServer.Schemas.ServerStatus
  alias Aesir.Commons.InterServer.Schemas.Session

  require Logger

  @tables [
    ServerStatus,
    Session,
    OnlineUser,
    CharacterLocation
  ]

  @doc """
  Recreates all Memento tables with current schemas.
  Useful when table structure changes during development.
  """
  def recreate_all_tables do
    Logger.info("Recreating all Memento tables...")

    Enum.each(@tables, &recreate_table/1)

    Logger.info("All tables recreated successfully")
    :ok
  end

  @doc """
  Recreates a specific Memento table.
  """
  def recreate_table(table_module) do
    Logger.debug("Recreating table #{inspect(table_module)}")

    # Stop Mnesia if needed
    ensure_mnesia_started()

    # Delete the table if it exists
    case :mnesia.delete_table(table_module) do
      {:atomic, :ok} ->
        Logger.debug("Deleted existing table #{inspect(table_module)}")

      {:aborted, {:no_exists, _}} ->
        Logger.debug("Table #{inspect(table_module)} doesn't exist, creating new")

      {:aborted, reason} ->
        Logger.warning("Failed to delete table #{inspect(table_module)}: #{inspect(reason)}")
    end

    # Create the table with the current schema
    case Memento.Table.create(table_module, disc_copies: [node()]) do
      :ok ->
        Logger.debug("Created table #{inspect(table_module)}")
        :ok

      {:error, reason} ->
        Logger.error("Failed to create table #{inspect(table_module)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Clears all data from tables without dropping them.
  """
  def clear_all_tables do
    Logger.debug("Clearing all Memento tables...")

    Enum.each(@tables, &clear_table/1)

    :ok
  end

  @doc """
  Clears all data from a specific table.
  """
  def clear_table(table_module) do
    result =
      Memento.transaction(fn ->
        records = Memento.Query.all(table_module)

        Enum.each(records, fn record ->
          # Get the key field (first attribute in the table definition)
          attrs = get_table_attributes(table_module)

          # credo:disable-for-next-line Credo.Check.Refactor.Nesting
          if attrs == [] do
            Logger.warning("No attributes found for table #{inspect(table_module)}")
          else
            [key_field | _] = attrs
            key = Map.get(record, key_field)
            Memento.Query.delete(table_module, key)
          end
        end)
      end)

    case result do
      {:ok, _} ->
        Logger.debug("Cleared table #{inspect(table_module)}")
        :ok

      :ok ->
        Logger.debug("Cleared table #{inspect(table_module)}")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to clear table #{inspect(table_module)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Ensures all tables exist with correct schemas.
  Creates tables if they don't exist, recreates if schema mismatch.
  """
  def ensure_tables_exist do
    Logger.debug("Ensuring all tables exist with correct schemas...")

    ensure_mnesia_started()

    Enum.each(@tables, fn table_module ->
      case check_table_schema(table_module) do
        :ok ->
          Logger.debug("Table #{inspect(table_module)} schema is correct")

        {:error, :no_table} ->
          Logger.debug("Table #{inspect(table_module)} doesn't exist, creating...")
          recreate_table(table_module)

        {:error, :schema_mismatch} ->
          Logger.warning("Table #{inspect(table_module)} has wrong schema, recreating...")
          recreate_table(table_module)
      end
    end)

    :ok
  end

  @doc """
  Resets the test environment by clearing all tables.
  Used in test setup.
  """
  def reset_test_environment do
    ensure_mnesia_started()
    clear_all_tables()
    :ok
  end

  # Private functions

  defp ensure_mnesia_started do
    case :mnesia.system_info(:is_running) do
      :yes -> :ok
      :no -> :mnesia.start()
      _ -> :mnesia.start()
    end
  end

  defp check_table_schema(table_module) do
    # Get expected attributes from the Memento table definition
    expected_attributes = get_table_attributes(table_module)

    case :mnesia.table_info(table_module, :attributes) do
      {:EXIT, _} ->
        {:error, :no_table}

      actual_attributes ->
        if attributes_match?(expected_attributes, actual_attributes) do
          :ok
        else
          Logger.debug("Expected attributes: #{inspect(expected_attributes)}")
          Logger.debug("Actual attributes: #{inspect(actual_attributes)}")
          {:error, :schema_mismatch}
        end
    end
  rescue
    _ -> {:error, :no_table}
  end

  defp get_table_attributes(table_module) do
    # Define expected attributes for each table
    # These must match what's defined in the module's "use Memento.Table" block
    case table_module do
      Aesir.Commons.InterServer.Schemas.Session ->
        [
          :account_id,
          :login_id1,
          :login_id2,
          :auth_code,
          :username,
          :state,
          :current_server,
          :current_char_id,
          :node,
          :created_at,
          :last_activity
        ]

      Aesir.Commons.InterServer.Schemas.OnlineUser ->
        [:account_id, :username, :server_type, :server_node, :last_seen, :character_id, :map_name]

      Aesir.Commons.InterServer.Schemas.ServerStatus ->
        [
          :server_id,
          :server_type,
          :server_node,
          :status,
          :player_count,
          :max_players,
          :ip,
          :port,
          :last_heartbeat,
          :metadata
        ]

      Aesir.Commons.InterServer.Schemas.CharacterLocation ->
        [:char_id, :account_id, :map_name, :x, :y, :node, :last_update]

      _ ->
        # Try to get from Mnesia if table exists
        try do
          :mnesia.table_info(table_module, :attributes)
        rescue
          _ -> []
        end
    end
  end

  defp attributes_match?(expected, actual) do
    # Compare ignoring order
    MapSet.new(expected) == MapSet.new(actual)
  end
end
