defmodule Aesir.ZoneServer.EtsTable do
  use Agent

  require Logger

  def start_link(opts) do
    {seed, opts} = Keyword.pop(opts, :seed)

    Agent.start_link(fn -> init_tables(seed) end, Keyword.take(opts, [:name]))
  end

  defp init_tables(seed) do
    spatial_index_tables(seed)
    core_runtime_tables(seed)
    map_cache_tables(seed)
    status_tables(seed)
    job_data_tables(seed)
    status_effect_tables(seed)
    unit_registry_tables(seed)

    :ok
  end

  defp spatial_index_tables(seed) do
    # Table for player positions: {char_id, {map_name, x, y}}
    :ets.new(
      table_for(:player_positions, seed),
      [:set, :public, :named_table, read_concurrency: true]
    )

    # Spatial index by grid cell: {{map_name, cell_x, cell_y}, MapSet.t(char_id)}
    :ets.new(
      table_for(:spatial_index, seed),
      [:set, :public, :named_table, read_concurrency: true]
    )

    # Visibility pairs: {{observer_id, observed_id}, true}
    :ets.new(
      table_for(:visibility_pairs, seed),
      [:set, :public, :named_table, read_concurrency: true]
    )
  end

  defp core_runtime_tables(seed) do
    :ets.new(table_for(:status_instances, seed), [:set, :public, :named_table])
  end

  defp map_cache_tables(seed) do
    :ets.new(table_for(:map_cache, seed), [:set, :public, :named_table, read_concurrency: true])
  end

  defp status_tables(seed) do
    :ets.new(
      table_for(:player_statuses, seed),
      [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ]
    )
  end

  defp job_data_tables(seed) do
    :ets.new(table_for(:job_data_by_id, seed), [
      :named_table,
      :set,
      :public,
      read_concurrency: true
    ])

    :ets.new(table_for(:job_data_by_name, seed), [
      :named_table,
      :set,
      :public,
      read_concurrency: true
    ])
  end

  defp status_effect_tables(seed) do
    :ets.new(table_for(:status_effect_definitions, seed), [:set, :public, :named_table])
  end

  defp unit_registry_tables(seed) do
    # Unit registry: {{unit_type, unit_id}, {module, state, pid}}
    :ets.new(
      table_for(:unit_registry, seed),
      [
        :set,
        :public,
        :named_table,
        read_concurrency: true,
        write_concurrency: true
      ]
    )
  end

  if Mix.env() == :test do
    def table_for(table, seed \\ nil) do
      seed = ProcessTree.get({__MODULE__, :seed}) || seed
      table_as_string = Atom.to_string(table)
      prefixed_table = "#{seed}_#{table_as_string}"
      String.to_atom(prefixed_table)
    end
  else
    def table_for(table, _ \\ nil) do
      table
    end
  end
end
