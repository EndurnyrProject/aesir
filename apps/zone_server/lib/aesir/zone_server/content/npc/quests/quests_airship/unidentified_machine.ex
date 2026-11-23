defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAirship.UnidentifiedMachine do
  @moduledoc """
  Describes an unidentified machine in the Cherno workshop.

  ## Credits

  - Original from rAthena, authors and contributors:
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - brianluau
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ein_in01",
        x: 122,
        y: 103,
        dir: 5,
        sprite: 111,
        name: "Unidentified Machine",
        scope: :shared,
        unique_name: "Unidentified Machine#ein"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("^3355FFIt's...")
    |> mes("It's a really")
    |> mes("strange looking")
    |> mes("machine. Does it")
    |> mes("even do anything?^000000")
    |> close()
  end
end
