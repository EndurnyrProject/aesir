defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns.PrtFild01 do
  @moduledoc false
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs.Poring

  use Aesir.ZoneServer.Mmo.MobManagement.Spawns.Definition,
    map: "prt_fild01",
    spawns: [
      %{mob: Poring, amount: 1, respawn_time: 10_000, area: %{x: 110, y: 203, xs: 5, ys: 5}}
    ]
end
