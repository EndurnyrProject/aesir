defmodule Aesir.ZoneServer.Content.Npc.Cities.Umbala.Yuwooki do
  @moduledoc """
  Shares Yuwooki's experience learning Umbalan culture and courtship customs.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Fusion Dev Team
    - Muad Dib
    - Darkchild

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "umbala",
        x: 80,
        y: 146,
        dir: 4,
        sprite: 753,
        name: "Yuwooki",
        scope: :shared,
        unique_name: "Yuwooki#um"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Yuwooki]")
    |> mes("Umbah umbah woogawoo...")
    |> mes("oops, sorry! I'm so used")
    |> mes("to speaking in Utan by now.")
    |> mes("It's a pleasure to meet you.")
    |> next()
    |> mes("[Yuwooki]")
    |> mes("I never imagined that I would")
    |> mes("meet another person from")
    |> mes("the homeland in this village.")
    |> mes("Hahahahah~!")
    |> next()
    |> mes("[Yuwooki]")
    |> mes("I came here to seek strong people")
    |> mes("to help me master my fighting")
    |> mes("skills. But I was soon frustrated")
    |> mes("because it took me a long")
    |> mes("time to learn the language...")
    |> next()
    |> mes("[Yuwooki]")
    |> mes("Well, now I am kind of used to my")
    |> mes("circumstances. Even though it")
    |> mes("took me a while to used to")
    |> mes("Utan culture. Hahahaha~!")
    |> next()
    |> mes("[Yuwooki]")
    |> mes("But you know what was the weirdest")
    |> mes("thing I found out about Utan")
    |> mes("culture? At first the Utan men")
    |> mes("seemed to have, shall we say, a")
    |> mes("strong species preservation instinct.")
    |> next()
    |> mes("[Yuwooki]")
    |> mes("There are many Utan playboys in")
    |> mes("this village. Some may think")
    |> mes("the Utans are primitive in")
    |> mes("this respect, but...")
    |> next()
    |> mes("[Yuwooki]")
    |> mes("As I learned more about them,")
    |> mes("I eventually realized that their")
    |> mes("courtship rituals are actually")
    |> mes("more advanced than anything the")
    |> mes("Rune-Midgarts culture has to offer.")
    |> next()
    |> mes("[Yuwooki]")
    |> mes("It's really quite fascinating.")
    |> mes("I'm actually still learning")
    |> mes("quite much from the Utan")
    |> mes("playboys and their awesome methods.")
    |> close()
  end
end
