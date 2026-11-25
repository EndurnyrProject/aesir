defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Mikhail do
  @moduledoc """
  Mikhail hides in the fire pot during the quest.

  ## Behavior

  - His events hide his NPC appearance.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_in",
        x: 202,
        y: 269,
        dir: 5,
        sprite: 962,
        name: "Mikhail",
        scope: :shared,
        unique_name: "Mikhail#mos"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: hideonnpc(ctx, "Mikhail#mos")
  def on_event("OnEnable", ctx), do: hideonnpc(ctx, "Mikhail#mos")

  @impl true
  def on_talk(ctx), do: ctx
end
