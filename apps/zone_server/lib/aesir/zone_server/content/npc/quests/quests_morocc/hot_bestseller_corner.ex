defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMorocc.HotBestsellerCorner do
  @moduledoc """
  The bestseller shelf sends the player into a vision of a burning laboratory.

  ## Behavior

  - During the Crow of the Fate quest, finding the book triggers the vision.

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
        x: 100,
        y: 5,
        dir: 3,
        sprite: 111,
        name: "Hot Bestseller Corner",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :barmunt_crow, 0)

    if progress in [3, 4, 5] do
      find_book(ctx, progress)
    else
      ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp find_book(ctx, progress) do
    ctx =
      ctx
      |> mes(
        "^660000The countless number of books filling this room tell you why this place is called the Greatest Library of Juno, the City of Scholars.^000000"
      )
      |> next()
      |> mes(
        "^660000Books tagged as 'Bestseller of The Month' are stored in the middle of the shelf that's at your eye level.^000000"
      )
      |> next()
      |> mes("^660000It was not that difficult to find 'The Crow of the Fate'")
      |> mes("because it was the only book leaning against the wall of an empty shelf.^000000")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Ah, luckily there's one... Ahchoo!")
      |> specialeffect2(:venomdust)
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "Sniff... So now all I have to do is just check this out and deliver it to that Mammi fanatic."
      )
      |> next()
      |> mes("^FF0000-- BEEP --^000000")
      |> next()
      |> mes(
        "^660000You were about to pull out the book, complaining and grumbling, when suddenly it felt as if your brain exploded. You black out...^000000"
      )

    ctx = if progress == 3, do: set_char_var(ctx, :barmunt_crow, 4), else: ctx

    ctx
    |> close2()
    |> specialeffect2(:bash3d2)
    |> warp("que_ba", 247, 33)
  end
end
