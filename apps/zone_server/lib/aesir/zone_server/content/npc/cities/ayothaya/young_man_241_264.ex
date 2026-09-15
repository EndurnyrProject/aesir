defmodule Aesir.ZoneServer.Content.Npc.Cities.Ayothaya.YoungMan241264 do
  @moduledoc """
  Playfully challenges visitors to a fight in Ayothaya.

  ## Behavior

  - Lets the player accept or decline a playful challenge.
  - Reacts with a different emotion for each response.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayothaya",
        x: 241,
        y: 264,
        dir: 5,
        sprite: 843,
        name: "Young Man",
        scope: :shared,
        unique_name: "Young Man#5ayothaya2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Eik]")
      |> mes("Hey...")
      |> mes("You look pretty strong")
      |> mes("You wanna challenge")
      |> mes("me to a match?")
      |> next()
      |> select(["Sure!", "Nah~"])

    if choice == 1 do
      ctx
      |> mes("[Eik]")
      |> mes("Ow ow ow!")
      |> mes("I was just")
      |> mes("kidding, man!")
      |> next()
      |> mes("[Eik]")
      |> mes("I'm not so rude as to pick fights with strangers for no reason!")
      |> emotion(:kek)
      |> close()
    else
      ctx
      |> mes("[Eik]")
      |> mes(
        "Real power is developed after having thousands of matches with other people. So, don't be afraid of fighting, okay?"
      )
      |> emotion(:hng)
      |> close()
    end
  end
end
