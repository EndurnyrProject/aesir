defmodule Aesir.ZoneServer.Content.Npc.Cities.Gonryun.KunlunEnvoy187239 do
  @moduledoc """
  Directs arriving travelers north toward Kunlun.

  ## Credits

  - Original from rAthena, authors and Contributors
    - x[tsk]
    - KarLaeda

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gon_fild01",
        x: 187,
        y: 239,
        dir: 7,
        sprite: 776,
        name: "Kunlun Envoy",
        scope: :shared,
        unique_name: "Kunlun Envoy#gon3"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Zhang Quing Long]")
    |> mes("Please head north to enter Kunlun.")
    |> mes("I hope you will have a great time")
    |> mes("while staying in Kunlun.")
    |> close()
  end
end
