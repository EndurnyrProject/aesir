defmodule Aesir.ZoneServer.EtsTable do
  use Agent

  def start_link(opts) do
    {seed, opts} = Keyword.pop(opts, :seed)

    Agent.start_link(fn -> init_tables(seed) end, Keyword.take(opts, [:name]))
  end

  defp init_tables(seed) do
    spatial_index_tables(seed)
    movement_tables(seed)
    core_runtime_tables(seed)
    map_cache_tables(seed)
    status_tables(seed)
    status_effect_tables(seed)
    unit_registry_tables(seed)
    skill_unit_tables(seed)
    vending_registry_tables(seed)
    ground_item_tables(seed)
    script_var_tables(seed)

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

    # Per-map unit membership: {{map_name, unit_type, unit_id}}. An ordered_set
    # so map/type prefix selects traverse only the matching subtree instead of
    # scanning the whole position table.
    :ets.new(
      table_for(:map_units, seed),
      [:ordered_set, :public, :named_table, read_concurrency: true, write_concurrency: true]
    )
  end

  defp movement_tables(seed) do
    # Per-map movement dirty set: {{map_name, unit_type, unit_id}, move_state}
    :ets.new(
      table_for(:movement_dirty, seed),
      [:set, :public, :named_table, write_concurrency: true]
    )
  end

  defp core_runtime_tables(seed) do
    :ets.new(table_for(:status_instances, seed), [:set, :public, :named_table])
  end

  defp map_cache_tables(seed) do
    :ets.new(table_for(:map_cache, seed), [:set, :public, :named_table, read_concurrency: true])

    :ets.new(
      table_for(:dynamic_cell_contributions, seed),
      [:set, :public, :named_table, read_concurrency: true, write_concurrency: true]
    )

    :ets.new(
      table_for(:dynamic_cell_source_index, seed),
      [:bag, :public, :named_table, read_concurrency: true, write_concurrency: true]
    )
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

    :ets.new(table_for(:unit_registry_id_index, seed), [
      :bag,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  defp skill_unit_tables(seed) do
    :ets.new(
      table_for(:field_supports, seed),
      [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ]
    )

    :ets.new(
      table_for(:skill_units, seed),
      [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ]
    )

    :ets.new(
      table_for(:skill_unit_cells, seed),
      [:set, :public, :named_table, read_concurrency: true, write_concurrency: true]
    )

    for table <- [
          :skill_unit_coordinate_index,
          :skill_unit_caster_index,
          :skill_unit_target_index,
          :skill_unit_cell_coordinate_index,
          :skill_unit_group_cells_index,
          :skill_unit_group_observers
        ] do
      :ets.new(
        table_for(table, seed),
        [
          :bag,
          :public,
          :named_table,
          {:read_concurrency, true},
          {:write_concurrency, true}
        ]
      )
    end

    for table <- [:skill_unit_due_index, :skill_unit_expiry_index] do
      :ets.new(
        table_for(table, seed),
        [
          :ordered_set,
          :public,
          :named_table,
          {:read_concurrency, true},
          {:write_concurrency, true}
        ]
      )
    end

    for table <- [
          :skill_unit_observer_groups,
          :skill_unit_map_index,
          :skill_unit_cell_map_index,
          :skill_unit_visible_cell_map_index
        ] do
      :ets.new(
        table_for(table, seed),
        [:ordered_set, :public, :named_table, read_concurrency: true, write_concurrency: true]
      )
    end
  end

  defp vending_registry_tables(seed) do
    # Open vending shops keyed by vendor unit_id: {unit_id, {owner_pid, shop}}
    :ets.new(
      table_for(:vending_registry, seed),
      [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ]
    )
  end

  defp ground_item_tables(seed) do
    # Ground items keyed by {map_name, ground_id}: {{map_name, ground_id}, GroundItem.t()}
    :ets.new(
      table_for(:ground_items, seed),
      [
        :set,
        :public,
        :named_table,
        {:read_concurrency, true},
        {:write_concurrency, true}
      ]
    )
  end

  defp script_var_tables(seed) do
    # Server temp globals (rAthena $@var): {name, value}. Node-local, cleared
    # on restart. Permanent $ and #/## vars are Postgres-backed, not here.
    :ets.new(
      table_for(:server_temp_vars, seed),
      [:set, :public, :named_table, read_concurrency: true, write_concurrency: true]
    )

    # NPC-scope globals (rAthena .var): {{npc_source, name}, value}. Shared
    # across every placement of an NPC script for the server's lifetime.
    :ets.new(
      table_for(:npc_vars, seed),
      [:set, :public, :named_table, read_concurrency: true, write_concurrency: true]
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
