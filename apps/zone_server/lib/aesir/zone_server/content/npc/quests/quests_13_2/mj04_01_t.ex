defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Mj0401T do
  @moduledoc """
  Re-enables a mineral deposit after its timer expires.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_04",
        x: 1,
        y: 1,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#mj04_01_t"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnTimer60000", ctx), do: ctx |> enablenpc("#mj04_01") |> stopnpctimer()

  @impl true
  def on_talk(ctx), do: initnpctimer(ctx)
end
