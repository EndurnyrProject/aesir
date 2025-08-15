defmodule Aesir.Commons.MementoCluster.Manager do
  @moduledoc """
  GenServer that manages Memento/Mnesia cluster initialization and health monitoring.
  """
  use GenServer

  require Logger

  alias Aesir.Commons.MementoCluster.Config

  defstruct [
    :status,
    :cluster_nodes,
    :retry_count,
    :max_retries
  ]

  @doc """
  Starts the MementoCluster Manager.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns the current cluster status.
  """
  def cluster_status do
    GenServer.call(__MODULE__, :cluster_status)
  end

  @doc """
  Returns information about all tables.
  """
  def table_info do
    GenServer.call(__MODULE__, :table_info)
  end

  @doc """
  Manually trigger cluster join attempt.
  """
  def join_cluster_node(node) do
    GenServer.call(__MODULE__, {:join_cluster, node})
  end

  @doc """
  Re-attempt cluster discovery and joining.
  """
  def rediscover_cluster do
    GenServer.call(__MODULE__, :rediscover_cluster)
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("[MementoCluster:#{node()}] Starting Memento cluster manager...")

    state = %__MODULE__{
      status: :initializing,
      cluster_nodes: [],
      retry_count: 0,
      max_retries: 5
    }

    # Initialize synchronously to ensure tables are ready before SessionManager starts
    case initialize_cluster() do
      :ok ->
        Logger.info("[MementoCluster:#{node()}] Cluster initialized successfully during init")
        Phoenix.PubSub.broadcast(Aesir.PubSub, "cluster:ready", %{node: node(), status: :ready})
        {:ok, %{state | status: :ready}}

      {:error, reason} ->
        Logger.error(
          "[MementoCluster:#{node()}] Failed to initialize cluster during init: #{inspect(reason)}"
        )

        # Still start but schedule retry
        send(self(), :initialize)
        {:ok, state}
    end
  end

  @impl true
  def handle_info(:initialize, state) do
    Logger.info("[MementoCluster:#{node()}] Initializing Memento cluster...")

    case initialize_cluster() do
      :ok ->
        Logger.info("[MementoCluster:#{node()}] Cluster initialized successfully")

        # Broadcast cluster ready
        Phoenix.PubSub.broadcast(Aesir.PubSub, "cluster:ready", %{node: node(), status: :ready})

        {:noreply, %{state | status: :ready}}

      {:error, reason} ->
        Logger.error(
          "[MementoCluster:#{node()}] Failed to initialize cluster: #{inspect(reason)}"
        )

        if state.retry_count < state.max_retries do
          Process.send_after(self(), :initialize, 5_000)
          {:noreply, %{state | status: :error, retry_count: state.retry_count + 1}}
        else
          {:stop, {:shutdown, :max_retries_exceeded}, state}
        end
    end
  end

  @impl true
  def handle_call(:cluster_status, _from, state) do
    status = %{
      node: node(),
      status: state.status,
      running_nodes: get_running_nodes(),
      all_nodes: get_all_nodes(),
      tables: get_table_status()
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:table_info, _from, state) do
    info =
      Enum.map(Config.tables(), fn {module, _storage} ->
        %{
          table: module,
          size: get_table_size(module),
          memory: get_table_memory(module),
          nodes: get_table_nodes(module)
        }
      end)

    {:reply, info, state}
  end

  @impl true
  def handle_call({:join_cluster, target_node}, _from, state) do
    Logger.info("[MementoCluster:#{node()}] Manual join to #{target_node} requested")

    result =
      case Node.connect(target_node) do
        true ->
          case sync_with_node(target_node) do
            :ok ->
              {:ok, "Successfully joined cluster via #{target_node}"}

            error ->
              error
          end

        _ ->
          {:error, "Failed to connect to #{target_node}"}
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:rediscover_cluster, _from, state) do
    Logger.info("[MementoCluster:#{node()}] Rediscovering cluster nodes...")

    running_nodes = discover_cluster_nodes()

    result =
      case running_nodes do
        [] ->
          {:ok, "No cluster nodes found, remaining standalone"}

        [head | _] ->
          case sync_with_node(head) do
            :ok ->
              {:ok, "Successfully synced with cluster via #{head}"}

            error ->
              error
          end
      end

    {:reply, result, state}
  end

  # Private Functions

  defp initialize_cluster do
    with :ok <- ensure_memento_started(),
         :ok <- setup_cluster(),
         :ok <- initialize_tables(),
         :ok <- wait_for_tables() do
      :ok
    else
      error ->
        Logger.error("[MementoCluster:#{node()}] Initialization failed: #{inspect(error)}")
        error
    end
  end

  defp ensure_memento_started do
    case Memento.system() do
      %{is_running: :yes} ->
        Logger.debug("[MementoCluster:#{node()}] Memento already running")
        :ok

      _ ->
        Logger.info("[MementoCluster:#{node()}] Starting Memento...")

        case Memento.start() do
          :ok ->
            :ok

          {:error, {:already_started, :mnesia}} ->
            Logger.debug("[MementoCluster:#{node()}] Mnesia already started")
            :ok

          error ->
            error
        end
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp setup_cluster do
    if Config.auto_cluster?() do
      # First check if we're already connected to nodes (like when using libcluster)
      connected = Node.list()
      configured = Config.cluster_nodes()

      # Find configured nodes we're already connected to
      cluster_candidates =
        Enum.filter(configured, fn node ->
          node != node() and node in connected
        end)

      case cluster_candidates do
        [] ->
          # No connected nodes, try discovery
          cluster_nodes = discover_cluster_nodes()

          case cluster_nodes do
            [] ->
              Logger.info(
                "[MementoCluster:#{node()}] No cluster nodes found, initializing as primary"
              )

              create_schema()

            nodes ->
              Logger.info("[MementoCluster:#{node()}] Found cluster nodes: #{inspect(nodes)}")
              join_cluster(nodes)
          end

        candidates ->
          # We have connected nodes - check if any have Mnesia running
          running =
            Enum.filter(candidates, fn candidate ->
              # credo:disable-for-next-line Credo.Check.Refactor.Nesting
              case :rpc.call(candidate, :mnesia, :system_info, [:is_running], 5_000) do
                :yes -> true
                _ -> false
              end
            end)

          case running do
            [] ->
              Logger.info(
                "[MementoCluster:#{node()}] Connected nodes don't have Mnesia, initializing as primary"
              )

              create_schema()

            [head | _] ->
              Logger.info(
                "[MementoCluster:#{node()}] Found running Mnesia on #{head}, attempting to join"
              )

              join_cluster([head])
          end
      end
    else
      Logger.info("[MementoCluster:#{node()}] Auto-clustering disabled, initializing standalone")
      create_schema()
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp discover_cluster_nodes do
    configured_nodes = Config.cluster_nodes()

    # Check already connected nodes first (like Mnesiac does)
    connected_nodes = Node.list()

    # Filter configured nodes that are already connected
    initial_candidates =
      Enum.filter(configured_nodes, fn node ->
        node != node() and node in connected_nodes
      end)

    # If no connected nodes, try to connect to configured ones
    cluster_candidates =
      if initial_candidates == [] do
        Enum.each(configured_nodes, fn node ->
          if node != node() do
            # credo:disable-for-next-line Credo.Check.Refactor.Nesting
            case Node.connect(node) do
              true -> Logger.debug("[MementoCluster:#{node()}] Connected to #{node}")
              false -> Logger.debug("[MementoCluster:#{node()}] Failed to connect to #{node}")
              :ignored -> Logger.debug("[MementoCluster:#{node()}] Connection to #{node} ignored")
            end
          end
        end)

        # Small delay to allow connections to establish
        Process.sleep(100)

        # Re-check connected nodes
        new_connected = Node.list()

        Enum.filter(configured_nodes, fn node ->
          node != node() and node in new_connected
        end)
      else
        initial_candidates
      end

    # Check which nodes have Mnesia/Memento running and are in the same cluster
    running_nodes =
      Enum.filter(cluster_candidates, fn candidate_node ->
        case :rpc.call(candidate_node, :mnesia, :system_info, [:is_running], 5_000) do
          :yes ->
            # Check if this node is part of their cluster
            case :rpc.call(candidate_node, :mnesia, :system_info, [:db_nodes], 5_000) do
              nodes when is_list(nodes) ->
                Logger.debug(
                  "[MementoCluster:#{node()}] #{candidate_node} has db_nodes: #{inspect(nodes)}"
                )

                true

              _ ->
                false
            end

          _ ->
            false
        end
      end)

    Logger.info(
      "[MementoCluster:#{node()}] Connected: #{inspect(connected_nodes)}, Mnesia running: #{inspect(running_nodes)}"
    )

    running_nodes
  end

  defp create_schema do
    case Memento.Schema.create([node()]) do
      :ok ->
        Logger.info("[MementoCluster:#{node()}] Schema created successfully")
        # Set schema to disc_copies for persistence
        set_schema_storage_type()

      {:error, {_, {:already_exists, _}}} ->
        Logger.debug("[MementoCluster:#{node()}] Schema already exists")
        # Ensure schema is set to disc_copies even if it already exists
        set_schema_storage_type()

      error ->
        error
    end
  end

  defp set_schema_storage_type do
    case Memento.Schema.set_storage_type(node(), :disc_copies) do
      :ok ->
        Logger.debug("[MementoCluster:#{node()}] Schema set to disc_copies")
        :ok

      {:error, {:already_exists, :schema, _, _}} ->
        Logger.debug("[MementoCluster:#{node()}] Schema already disc_copies")
        :ok

      error ->
        Logger.warning(
          "[MementoCluster:#{node()}] Failed to set schema storage type: #{inspect(error)}"
        )

        # Continue anyway - some tables might work with ram_copies
        :ok
    end
  end

  defp join_cluster([head | _]) do
    Logger.info("[MementoCluster:#{node()}] Attempting to join cluster via #{head}")

    case sync_with_node(head) do
      :ok ->
        Logger.info("[MementoCluster:#{node()}] Successfully joined cluster")
        :ok

      {:error, reason} ->
        Logger.warning("[MementoCluster:#{node()}] Failed to join cluster: #{inspect(reason)}")
        Logger.info("[MementoCluster:#{node()}] Falling back to standalone mode")

        # Create standalone schema
        create_schema()
    end
  end

  defp sync_with_node(target_node) do
    # Check if we can join without stopping (if we haven't created tables yet)
    local_tables = :mnesia.system_info(:local_tables)

    # If we only have schema table, we can join without stopping
    if local_tables == [:schema] do
      Logger.info("[MementoCluster:#{node()}] No tables created yet, joining directly")

      with :ok <- connect_to_cluster(target_node),
           :ok <- copy_schema(),
           :ok <- sync_tables_from_node(target_node) do
        :ok
      else
        error -> error
      end
    else
      Logger.info("[MementoCluster:#{node()}] Local tables exist, need to restart Mnesia to join")

      with :ok <- Memento.stop(),
           :ok <- delete_schema(),
           :ok <- ensure_memento_started(),
           :ok <- connect_to_cluster(target_node),
           :ok <- copy_schema(),
           :ok <- sync_tables_from_node(target_node) do
        :ok
      else
        error ->
          # Restart Memento on error
          ensure_memento_started()
          error
      end
    end
  end

  defp sync_tables_from_node(target_node) do
    Logger.info("[MementoCluster:#{node()}] Syncing tables from #{target_node}")

    # Get list of tables from remote node
    case :rpc.call(target_node, :mnesia, :system_info, [:tables], 5_000) do
      {:badrpc, reason} ->
        {:error, {:rpc_failed, reason}}

      remote_tables ->
        # Copy each configured table
        results =
          Enum.map(Config.tables(), fn {module, storage_type} ->
            if module in remote_tables do
              Logger.debug(
                "[MementoCluster:#{node()}] Copying table #{module} from #{target_node}"
              )

              # credo:disable-for-next-line Credo.Check.Refactor.Nesting
              case Memento.Table.create_copy(module, node(), storage_type) do
                :ok ->
                  :ok

                {:error, {:already_exists, _, _}} ->
                  Logger.debug("[MementoCluster:#{node()}] Table #{module} copy already exists")
                  :ok

                error ->
                  error
              end
            else
              Logger.debug(
                "[MementoCluster:#{node()}] Table #{module} not found on #{target_node}, creating locally"
              )

              Config.ensure_table(module, storage_type)
            end
          end)

        case Enum.find(results, &(&1 != :ok)) do
          nil -> :ok
          error -> error
        end
    end
  end

  defp delete_schema do
    case Memento.Schema.delete([node()]) do
      :ok -> :ok
      {:error, {:no_exists, _}} -> :ok
      error -> error
    end
  end

  defp connect_to_cluster(cluster_node) do
    case Memento.add_nodes(cluster_node) do
      {:ok, _nodes} ->
        Logger.info("[MementoCluster:#{node()}] Connected to cluster")
        :ok

      error ->
        Logger.error("[MementoCluster:#{node()}] Failed to connect to cluster: #{inspect(error)}")
        error
    end
  end

  defp copy_schema do
    case Memento.Schema.set_storage_type(node(), :disc_copies) do
      :ok -> :ok
      {:error, {:already_exists, _, _, _}} -> :ok
      error -> error
    end
  end

  defp initialize_tables do
    Logger.info("[MementoCluster:#{node()}] Initializing tables...")

    results =
      Enum.map(Config.tables(), fn {module, storage_type} ->
        Logger.debug("[MementoCluster:#{node()}] Ensuring table #{module} with #{storage_type}")
        Config.ensure_table(module, storage_type)
      end)

    case Enum.find(results, &(&1 != :ok)) do
      nil ->
        Logger.info("[MementoCluster:#{node()}] All tables initialized successfully")
        :ok

      error ->
        Logger.error("[MementoCluster:#{node()}] Table initialization failed: #{inspect(error)}")
        error
    end
  end

  defp wait_for_tables do
    tables = Enum.map(Config.tables(), fn {module, _} -> module end)
    timeout = Config.table_load_timeout()

    Logger.info("[MementoCluster:#{node()}] Waiting for tables to load...")

    case Memento.wait(tables, timeout) do
      :ok ->
        Logger.info("[MementoCluster:#{node()}] All tables loaded successfully")
        :ok

      error ->
        Logger.error("[MementoCluster:#{node()}] Table load timeout: #{inspect(error)}")
        error
    end
  end

  defp get_running_nodes do
    case Memento.system() do
      %{running_db_nodes: nodes} -> nodes
      _ -> []
    end
  end

  defp get_all_nodes do
    case Memento.system() do
      %{db_nodes: nodes} -> nodes
      _ -> []
    end
  end

  defp get_table_status do
    Enum.map(Config.tables(), fn {module, _} ->
      %{
        table: module,
        loaded: table_loaded?(module),
        size: get_table_size(module)
      }
    end)
  end

  defp table_loaded?(module) do
    case Memento.Table.info(module, :size) do
      {:error, _} -> false
      _ -> true
    end
  end

  defp get_table_size(module) do
    case Memento.Table.info(module, :size) do
      {:error, _} -> 0
      size -> size
    end
  end

  defp get_table_memory(module) do
    case Memento.Table.info(module, :memory) do
      {:error, _} -> 0
      memory -> memory
    end
  end

  defp get_table_nodes(module) do
    case Memento.Table.info(module, :disc_copies) do
      {:error, _} ->
        case Memento.Table.info(module, :ram_copies) do
          {:error, _} -> []
          nodes -> nodes
        end

      nodes ->
        nodes
    end
  end
end
