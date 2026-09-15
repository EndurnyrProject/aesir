defmodule Aesir.ZoneServer.Content.Npc.Cities.Aldebaran.Rs125 do
  @moduledoc """
  Recounts a robotic athlete’s plans to restore his family’s racing reputation.

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
        x: 232,
        y: 241,
        dir: 4,
        sprite: 48,
        name: "RS125",
        scope: :shared,
        unique_name: "RS125#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[RS125]")
      |> mes("I may sound inhuman rather robotic")
      |> mes("however, I hope you will not be afraid of me. I am as humane as you are.")
      |> next()
      |> mes("[RS125]")
      |> mes("I may have a machine heart and I may disturb you with loud noises from the heart,")
      |> mes("that will never stop me from running for future of Al De Baran.")
      |> next()
      |> select(["Listen to his story.", "End Conversation"])

    if choice == 1 do
      ctx
      |> mes("[RS125]")
      |> mes("It's been 3 years already.")
      |> mes(
        "My brother 996 used to be a short track athlete in the Al De Baran city field team."
      )
      |> mes("Back then, people gave him a nickname, 'Al De Baran's Peco Peco',")
      |> mes("for his amazingly fast legs...")
      |> next()
      |> mes("[RS125]")
      |> mes("He became so popular for his exciting play,")
      |> mes("so every time when the 'Al De Baran Turbo Track' was held once every 4 years,")
      |> mes("many people from all over the continent came to this city only to see my brother.")
      |> mes("I was his manager at the time and I was so stressed out because of his fans.")
      |> next()
      |> mes("[RS125]")
      |> mes("However, there is nothing last forever...")
      |> mes("One day, a girl from Payon beat my brother from a game.")
      |> next()
      |> mes("[RS125]")
      |> mes("My brother couldn't accept the fact that he lost the game")
      |> mes("so he did too much of practice and had a serious heart attack.")
      |> mes("He is still in bed.")
      |> next()
      |> mes("[RS125]")
      |> mes("I am my brother's only hope and the future of Al De Baran!")
      |> mes("Please wish me luck, I will beat her, 'Breezy Havana' from Payon!")
      |> close()
    else
      ctx
      |> mes("[RS125]")
      |> mes("I want to travel around the world one of these days.")
      |> mes("If I can see the ocean from the port of Alberta, it must be so wonderful.")
      |> mes(
        "After the next year's athletic competition, I will go on a round-the-world tour with my brother."
      )
      |> close()
    end
  end
end
