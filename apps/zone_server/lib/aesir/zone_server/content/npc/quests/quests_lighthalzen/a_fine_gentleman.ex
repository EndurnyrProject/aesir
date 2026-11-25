defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.AFineGentleman do
  @moduledoc """
  Keeps Keshnaar hidden until the guard calls him.

  ## Behavior


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
        x: 96,
        y: 69,
        dir: 2,
        sprite: 754,
        name: "A Fine Gentleman",
        scope: :shared
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: hide(ctx)
  @impl true
  def on_talk(ctx), do: hide(ctx)

  defp hide(ctx) do
    disablenpc(ctx, "A Fine Gentleman")
  end
end
