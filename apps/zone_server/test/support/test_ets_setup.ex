defmodule Aesir.TestEtsSetup do
  import ExUnit.Callbacks

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Npc.Warps

  def setup_ets_tables(_) do
    seed =
      5
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    _pid = start_supervised({EtsTable, seed: seed}, [])

    Process.put(
      {EtsTable, :seed},
      seed
    )

    for table <- [
          :skill_units,
          :skill_unit_cells,
          :skill_unit_coordinate_index,
          :skill_unit_group_cells_index,
          :skill_unit_map_index,
          :skill_unit_due_index,
          :skill_unit_expiry_index,
          :skill_unit_caster_index,
          :skill_unit_target_index,
          :field_supports,
          :dynamic_cell_contributions,
          :dynamic_cell_source_index
        ] do
      :ets.delete_all_objects(EtsTable.table_for(table))
    end

    :ok = Interpreter.init()
    :ok = MapCache.init()

    # Pre-warm an empty warp index so `Warps.for_map/1` returns `:error`
    # without triggering the lazy loader (which would otherwise sanitize the
    # real warp files against the un-stubbed `MapCache`, dropping them all and
    # logging noise). Tests that exercise real warp data erase this and call
    # `Warps.reload/0`.
    :persistent_term.put(Warps, %{by_map: %{}})

    :ok
  end
end
