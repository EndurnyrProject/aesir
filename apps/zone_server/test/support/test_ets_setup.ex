defmodule Aesir.TestEtsSetup do
  import ExUnit.Callbacks

  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Mmo.JobData
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter

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
    :ok = JobData.init()

    :ok
  end
end
