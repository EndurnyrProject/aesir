defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLighthalzen.File do
  @moduledoc """
  A file lists three subjects and their obscured details.

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
        x: 89,
        y: 15,
        dir: 3,
        sprite: 111,
        name: "File",
        scope: :shared,
        unique_name: "File#li"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("Name: Engeod")
    |> mes("Age: XX")
    |> mes("Height: XXX")
    |> mes("Weight: XX")
    |> next()
    |> mes("Name: Kashutii")
    |> mes("Age: XX")
    |> mes("Height: XXX")
    |> mes("Weight: XX")
    |> next()
    |> mes("Name: Prufoz")
    |> mes("Age: XX")
    |> mes("Height: XXX")
    |> mes("Weight: XX")
    |> close()
  end
end
