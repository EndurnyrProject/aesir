defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.LiBird do
  @moduledoc """
  A talking bird mocks visitors.

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
        map: "lhz_que01",
        x: 90,
        y: 71,
        dir: 5,
        sprite: 1019,
        name: "",
        scope: :shared,
        unique_name: "#li_bird",
        trigger: {3, 3}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: on_talk(ctx)

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Peco Peco]")
    |> mes("You're a fool!")
    |> mes("You're a fool!")
    |> mes("You're a fool!")
    |> close()
  end
end
