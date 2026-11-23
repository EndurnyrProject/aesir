defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Ve03T do
  @moduledoc """
  Re-enables mineral deposit 3 after 40 seconds.

  ## Credits

  - Original from rAthena, authors and contributors:
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
        map: "ve_fild03",
        x: 1,
        y: 1,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#ve_03_t"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer40000", ctx) do
    ctx |> enablenpc("#ve_03") |> stopnpctimer()
  end

  @impl true
  def on_talk(ctx), do: initnpctimer(ctx)
end
