defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.ReadingGirl do
  @moduledoc """
  Yunia talks about the book she is reading.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - SinSloth
    - Samuray22
    - L0ne_W0lf
    - Gepard
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
        map: "yuno_in04",
        x: 180,
        y: 106,
        dir: 3,
        sprite: 73,
        name: "Reading Girl",
        scope: :shared,
        unique_name: "Reading Girl#moc_girl1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Excuse me, but may I ask")
      |> mes("you a question?")
      |> next()
      |> mes("[Yunia]")
      |> mes("Eh? Oh, I'm sorry, I was")
      |> mes("so busy reading this book!")
      |> mes("So, uh, what exactly did")
      |> mes("you want to ask me?")
      |> next()
      |> select(["What are you reading?"])

    ctx
    |> mes("[Yunia]")
    |> mes("Ah! This is one of the best sellers of Joshua Vansei's.")
    |> mes(
      "The main character is a writer, and it's so touching that this guy writes a story of his mistress..."
    )
    |> next()
    |> mes("[Yunia]")
    |> mes("Oh.. I can't wait to see Hoein Special..")
    |> mes("And this, you could have a look if you want to.")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Oh, now, I shouldn't.")
    |> mes("Looks like the cover's rounded with a red strap,")
    |> mes("which..I really think is for adults only.")
    |> mes("ex..cuse me~!")
    |> close()
  end
end
