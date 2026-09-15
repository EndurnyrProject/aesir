defmodule Aesir.ZoneServer.Content.Npc.Cities.Jawaii.TavernLady do
  @moduledoc """
  Warns Jawaii visitors about the island tavern.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - DNett123
    - L0ne_w0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jawaii",
        x: 188,
        y: 218,
        dir: 7,
        sprite: 80,
        name: "Tavern Lady",
        scope: :shared,
        unique_name: "Tavern Lady#Jawaii"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Lady]")
      |> mes("Oh, dear!")
      |> mes("You're not going")
      |> mes("to the tavern, are you?")
      |> next()
      |> select(["No, I am not.", "Hell yeah~"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("[Lady]")
        |> mes("Whew~!")
        |> mes("Thank goodness!")
        |> mes("It's just that...")
        |> mes("The tavern probably")
        |> mes("isn't the best place for")
        |> mes("you to enjoy yourself.")
        |> next()
      else
        ctx
      end

    ctx
    |> mes("[Lady]")
    |> mes(
      "Even though I work there, I still can't believe that kind of place exists! I mean, I thought alcohol was outlawed in the Rune-Midgarts Kingdom!"
    )
    |> next()
    |> mes("[Lady]")
    |> mes("I have no idea how singles are")
    |> mes(
      "able to find this place. But I've heard that lots of different people come here for different reasons."
    )
    |> next()
    |> mes("[Lady]")
    |> mes(
      "I've even seen unmarried single people coming here just to get drunk! Oh! And for some reason, people have been disappearing"
    )
    |> mes("from the tavern!")
    |> next()
    |> mes("[Lady]")
    |> mes("I wonder what's going on?")
    |> mes(
      "^666666*Sigh*^000000 I'm a waitress there, but still I just want to tell you not to go in there..."
    )
    |> close()
  end
end
