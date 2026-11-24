defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.Book do
  @moduledoc """
  Offers a library book that changes with the Juperos history quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
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
        x: 188,
        y: 118,
        dir: 4,
        sprite: 111,
        name: "Book",
        scope: :shared,
        unique_name: "Book#juperos"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if get_char_var(ctx, :yuno_hist, 0) > 7 do
      ctx =
        ctx
        |> mes("^8B6914*Self-Honesty*")
        |> mes("*'Benefits Fo' Life!'*")
        |> mes("By Stephen Oyoung")
        |> mes(" ")
        |> mes(" ")
        |> mes("Publisher:")
        |> mes("Wushu Publishing, Co.^000000")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("W-whoa!")
      |> mes("This book wasn't")
      |> mes("here before! It looks")
      |> mes("pretty interesting...")
      |> close()
    else
      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("You know what?")
        |> mes("I think I'll just flip")
        |> mes("through some pages")
        |> mes("from a random book.")
        |> mes("Hmmm, let's see...")
        |> next()
        |> mes("^8B6914''Admiral, the Kylorians are")
        |> mes("still advancing!'' Commander")
        |> mes("McKenrick announced without")
        |> mes("his usual swagger. ''They're...")
        |> mes("They're not stopping!'' But")
        |> mes("Admiral Leh's eyes were a cold,")
        |> mes("unfeeling shade of sternness.^000000")
        |> next()
        |> mes("^8B6914''Let the goddamned space")
        |> mes("aliens come,'' hissed Leh.")
        |> mes("''We don't stand a chance")
        |> mes("without the Zenoi Sword")
        |> mes("to summon the power of")
        |> mes("GOD-POING. It's... It's")
        |> mes("all over. Damn it all...''^000000")
        |> next()
        |> mes("^8B6914The doors burst open as")
        |> mes("Bucky flew into the room.")
        |> mes("''The Zenoi Sword! The")
        |> mes("Zenoi Sword! Someone's")
        |> mes("found it!'' the boy yelled.")
        |> mes("''Really?! We better hurry:")
        |> mes("Earth doesn't have much time!''^000000")
        |> next()

      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...")
      |> mes("......")
      |> mes("Whoa. I really")
      |> mes("should have read")
      |> mes("this masterpiece")
      |> mes("from the beginning...")
      |> close()
    end
  end
end
