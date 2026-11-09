defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Alberto do
  @moduledoc """
  Alberto, the frozen researcher of the Manuk field who awaits the coat the Instructor
  promised him.

  ## Behavior

  - On step 19, while the player carries the parcel, plays the coat delivery, consumes it, sets
    `ep13_newbs` to 20, hands over a Chocolate Pie and advances quest 11097 to 11098; without
    the parcel he only complains about the cold.
  - On step 20 he is still cold even with the coat.
  - On every other step he wonders about the strange structures.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "man_fild01",
        x: 80,
        y: 248,
        dir: 4,
        sprite: 934,
        name: "Alberto",
        scope: :shared,
        unique_name: "Alberto#ep13bs"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @parcel 6045
  @gift 12322

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :ep13_newbs, 0) do
      19 -> deliver_coat(ctx)
      20 -> still_cold(ctx)
      _step -> strange_structures(ctx)
    end
  end

  defp deliver_coat(ctx) do
    if count_item(ctx, @parcel) > 0 do
      opens_parcel(ctx)
    else
      freezing(ctx)
    end
  end

  defp opens_parcel(ctx) do
    ctx =
      ctx
      |> mes("[Alberto]")
      |> mes("Hhh, I am cold...")
      |> next()
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Mr. Alberto, take this.")
      |> mes("The Instructor sent")
      |> mes("me on an errand.")
      |> next()
      |> mes("[Alberto]")
      |> mes("I finally got it.")
      |> mes("My coat...sniff.")
      |> mes("It's freezing here.")
      |> emotion(:cry)
      |> next()
      |> mes("[Alberto]")
      |> mes("Sniff...")
      |> mes("- rustling sound -")
      |> next()
      |> mes("[Alberto]")
      |> mes("Ah, I am sorry but...")
      |> mes("My hands are so cold")
      |> mes("that I cannot open it.")
      |> mes("Can you open it for me?.")
      |> next()
      |> mes("- rustling sound -")
      |> mes("- Opening someone -")
      |> mes("- else's stuff makes -")
      |> mes("- me feel strange. -")
      |> next()

    ctx
    |> mes("[#{char_name(ctx, 0)}]")
    |> mes("Here it is.")
    |> mes("Hopefully it'll warm you up.")
    |> next()
    |> mes("[Alberto]")
    |> mes("Yes I really appreciate it.")
    |> mes("It makes me feel alive.")
    |> next()
    |> mes("[Alberto]")
    |> mes("Please tell the Instructor")
    |> mes("that I am still alive.")
    |> mes("Sniff.")
    |> emotion(:cry)
    |> delitem(@parcel, 1)
    |> set_char_var(:ep13_newbs, 20)
    |> give_item(@gift, 1)
    |> changequest(11097, 11098)
    |> close()
  end

  defp freezing(ctx) do
    ctx
    |> mes("[Alberto]")
    |> mes("It's so cold here~~")
    |> mes("the wind chills me to the bones~")
    |> emotion(:cry)
    |> close()
  end

  defp still_cold(ctx) do
    ctx
    |> mes("[Alberto]")
    |> mes("I am still cold even")
    |> mes("with this heavy coat.")
    |> mes("I need to order more clothes.")
    |> close()
  end

  defp strange_structures(ctx) do
    ctx
    |> mes("[Alberto]")
    |> mes("What are these weird")
    |> mes("structures set up")
    |> mes("here and there?")
    |> close()
  end
end
