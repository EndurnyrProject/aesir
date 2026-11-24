defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAmatsu.Soldier40167 do
  @moduledoc """
  Shares a rumor about the lord of the palace.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - MasterOfMuppets
    - L0ne_W0lf
    - Gepard
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ama_in02",
        x: 40,
        y: 167,
        dir: 3,
        sprite: 767,
        name: "Soldier",
        scope: :shared,
        unique_name: "Soldier#ama5"
      }
    ]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("[Goro]")
    |> mes("*Psst*... Please, be quiet.")
    |> mes("I will tell you a story, okay?")
    |> mes(" ")
    |> next()
    |> mes("[Goro]")
    |> mes("There is a rumor in Amatsu.")
    |> mes("The lord of this palace isn't")
    |> mes("real... *Psst*, Quiet!")
    |> mes("Don't panic and listen to me.")
    |> next()
    |> mes("[Goro]")
    |> mes("There is a real lord behind")
    |> mes("the kind lord and he is scheming")
    |> mes("something. He is controlling")
    |> mes("our town in some hidden place.")
    |> mes("...Our kind lord is just a figurehead~!")
    |> next()
    |> mes("[Goro]")
    |> mes("It's for real! Trust me~")
    |> mes("I saw him. The lord who was")
    |> mes("laughing at the town on the")
    |> mes("TenguGak!!")
    |> mes("Just don't tell anyone that I've told you this, okay?")
    |> close()
  end
end
