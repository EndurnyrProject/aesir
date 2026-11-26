defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Larjes166254 do
  @moduledoc """
  Hides Larjes when the monastery scene initializes.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nameless_n",
        x: 166,
        y: 254,
        dir: 0,
        sprite: 97,
        name: "Larjes",
        scope: :shared,
        unique_name: "Larjes#Monastery2"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: hideonnpc(ctx, "Larjes#Monastery2")

  @impl true
  def on_talk(ctx), do: ctx
end
