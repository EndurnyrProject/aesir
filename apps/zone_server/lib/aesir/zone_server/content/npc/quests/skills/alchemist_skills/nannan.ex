defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.AlchemistSkills.Nannan do
  @moduledoc """
  A Lighthalzen local who gossips about Broncher, the hard-drinking Alchemist.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - Samuray22
    - L0ne_W0lf
    - DracoRPG
    - Toms
    - SinSloth

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lighthalzen",
        x: 226,
        y: 210,
        dir: 3,
        sprite: 86,
        name: "Nannan",
        scope: :shared,
        unique_name: "Nannan#qsk_al"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Nannan]")
    |> mes("You know, I always thought that all Alchemists were bookish,")
    |> mes("scholarly types, their faces always buried in books and studying. But")
    |> mes("I managed to find one who doesn't fit that nerdy stereotype at all.")
    |> next()
    |> mes("[Nannan]")
    |> mes("This guy, what's-his-face,")
    |> mes("Broncher, is always wasting")
    |> mes("his time drinking. I guess he discovered the secret of turning")
    |> mes("water into Grade A booze. But at least he's not the stuffy type.")
    |> next()
    |> mes("[Nannan]")
    |> mes("I don't know how much")
    |> mes("help he'd be to an aspiring")
    |> mes("Alchemist, but in my opinion,")
    |> mes("the man is a fully fledged")
    |> mes("genius! At least, compared")
    |> mes("to a street guy like me...")
    |> close()
  end
end
