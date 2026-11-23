defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Hu04T do
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
        map: "hu_fild05",
        x: 1,
        y: 1,
        dir: 3,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#hu_04_t"
      }
    ]

  @impl true
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnTimer60000", ctx), do: ctx |> enablenpc("#hu_04") |> stopnpctimer()

  @impl true
  def on_talk(ctx), do: initnpctimer(ctx)
end
