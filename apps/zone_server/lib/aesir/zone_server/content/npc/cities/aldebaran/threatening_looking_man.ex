defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.ThreateningLookingMan do
  @moduledoc """
  Jokes with intruders and offers dubious advice about choosing mercenaries.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 223,
        y: 121,
        dir: 4,
        sprite: 63,
        name: "Threatening-Looking Man",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Threatening-Looking Man]")
      |> mes("Hey, you don't come inside someone else's house without permission.")
      |> mes("This is ridiculous!")
      |> mes(
        "How dare you to come inside of my house and talk to me as if that is a normal thing to do?"
      )
      |> next()
      |> mes("[Threatening-Looking Man]")
      |> mes("Hahahaha...chill out, I was just joking.")
      |> next()
      |> select(["Continue", "Quit"])

    if choice == 1 do
      ctx
      |> mes("[Threatening-Looking Man]")
      |> mes("You may know this already, but")
      |> mes("we have a system called, the mercenary system in this world.")
      |> mes("Yes, I am a mercenary soldier.")
      |> next()
      |> mes("[Threatening-Looking Man]")
      |> mes("It is simple. You just pay for someone to aid you in fight.")
      |> mes("Better mercenary soldier you want, more money you have to pay, you know?")
      |> next()
      |> mes("[Threatening-Looking Man]")
      |> mes("Let's stop talking about boring stuffs.")
      |> mes("I will tell you how you can find a good mercenary soldier.")
      |> next()
      |> mes("[Threatening-Looking Man]")
      |> mes("Check its nose if it is clean and wet.")
      |> mes("A good mercenary soldier must have the wet nose")
      |> mes("because it shows that the soldier is at his best in health condition.")
      |> mes("If the nose is dry, that means that he caught a cold.")
      |> next()
      |> mes("[Threatening-Looking Man]")
      |> mes("And don't forget to check the soldier's ankle.")
      |> mes("The best mercenary soldier has thin ankles and a white neck!")
      |> mes("If he has long hair, it's better! If the hair is permed and wavy, that's perfect!")
      |> next()
      |> mes("[Threatening-Looking Man]")
      |> mes("Lastly, you have to check whether he is ready to serve you with quality service!")
      |> mes("That means, he must do his best in aiding you in fight!")
      |> close()
    else
      ctx
      |> mes("[Threatening-Looking Man]")
      |> mes("Get out, now!")
      |> mes("If you a cop, show me a warrant,")
      |> mes("if you are a member of my family, prove it with your birth mark!")
      |> close()
    end
  end
end
