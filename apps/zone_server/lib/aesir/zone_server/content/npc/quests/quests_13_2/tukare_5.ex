defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Tukare5 do
  @moduledoc """
  Re-enables exhausted soldier 5 after one minute.

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
        map: "splendide",
        x: 1,
        y: 1,
        dir: 1,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#tukare_5"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer60000", ctx) do
    ctx |> enablenpc("Exhausted Soldier#5") |> stopnpctimer()
  end

  @impl true
  def on_talk(ctx), do: initnpctimer(ctx)
end
