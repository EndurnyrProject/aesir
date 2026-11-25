defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.Secretary7768 do
  @moduledoc """
  Keeps the president’s secretary hidden until she is needed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Samuray22
    - Gepard
    - Euphy
    - Joseph
    - Capuche
    - JohnnyPlayy
    - Persian
    - Vicious_Pucca
    - aoa00
    - Evera
    - MasterOfMuppets
    - Lupus
    - Lord Gywall
    - DeNy
    - Vicious
    - Playtester
    - Silent
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_pre",
        x: 77,
        y: 68,
        dir: 0,
        sprite: 862,
        name: "Secretary",
        scope: :shared,
        unique_name: "Secretary#2"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Secretary#2")

  @impl true
  def on_talk(ctx), do: disablenpc(ctx, "Secretary#2")
end
