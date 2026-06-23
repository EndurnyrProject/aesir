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

    :ok = Interpreter.init()
    :ok = MapCache.init()

    # Pre-warm an empty warp index so `Warps.for_map/1` returns `:error`
    # without triggering the lazy loader (whose boot-time validator would
    # raise against the un-stubbed `MapCache`). Tests that exercise real
    # warp data erase this and call `Warps.reload/0`.
    :persistent_term.put(Warps, %{by_map: %{}})

    :ok
  end
end
