defmodule Aesir.ZoneServer.Content.Npc.Cities.Einbech.Raust do
  @moduledoc """
  Angrily compares Einbech’s hardships with Einbroch’s prosperity.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Muad_Dib

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbech",
        x: 93,
        y: 139,
        dir: 5,
        sprite: 847,
        name: "Raust",
        scope: :shared,
        unique_name: "Raust#ein"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Raust]")
    |> mes("I don't get it!")
    |> mes("Einbroch gets bigger")
    |> mes("and fancier and our")
    |> mes("town gets dirtier and")
    |> mes("nastier. What the hell?!")
    |> next()
    |> mes("[Raust]")
    |> mes("Not only do the people")
    |> mes("here look more ragged, we're")
    |> mes("more tired and older looking")
    |> mes("even! It's dirty, it's crowded,")
    |> mes("everything in this city is total crap! What, you want a list?!")
    |> next()
    |> mes("[Raust]")
    |> mes("The food, literally, is")
    |> mes("garbage! The jobs here have")
    |> mes(
      "to be violations of human rights. There's barely any women here and the ones we do have are all stank anyway! Are you convinced yet?!"
    )
    |> next()
    |> mes("[Raust]")
    |> mes("Why is everything")
    |> mes("that's good over in")
    |> mes("Einbroch?! I hate this!")
    |> mes("^333333*Grumble*^000000")
    |> close()
  end
end
