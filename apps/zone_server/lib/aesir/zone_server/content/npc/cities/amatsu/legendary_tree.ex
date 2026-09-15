defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.LegendaryTree do
  @moduledoc """
  Reflects on Amatsu's legendary cherry tree through the visitor's latest conversation.

  ## Behavior

  - Changes its narration according to which nearby resident last described the tree.
  - Uses a gender-specific reflection after hearing about the White Dryad play.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "amatsu",
        x: 262,
        y: 197,
        dir: 1,
        sprite: 111,
        name: "Legendary Tree",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    case get_char_var(ctx, :jap_tree, 0) do
      1 -> reflect_on_proposals(ctx)
      2 -> reflect_on_white_dryad(ctx)
      3 -> reflect_on_comfort(ctx)
      4 -> reflect_on_dread(ctx)
      _ -> inspect_tree(ctx)
    end
  end

  defp reflect_on_proposals(ctx) do
    ctx
    |> mes("^3355FFAs she mentioned, this tree")
    |> mes("seems to be a famous place")
    |> mes("for proposing lovers.")
    |> mes("There were several carved symbols")
    |> mes("of hearts and initials of lovers")
    |> mes("on the bark.^000000")
    |> next()
    |> mes("^3355FFBesides proposals, people")
    |> mes("gather under this tree when")
    |> mes("they discuss important")
    |> mes("matters. I could listen to")
    |> mes("all kinds of stories")
    |> mes("in this magnificent place.^000000")
    |> close()
  end

  defp reflect_on_white_dryad(ctx) do
    ctx =
      ctx
      |> mes("^3355FFThe legendary play, 'White Dryad'.....")
      |> mes("I never heard about that title but")
      |> mes("it sounds familiar.")
      |> mes("Nymph of cherry tree... What would")
      |> mes("be her position in the play?^000000")
      |> next()

    if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
      ctx
      |> mes("^3355FFI would like to find")
      |> mes("a person who is talented")
      |> mes("in acting and help her until")
      |> mes("she performs the play. However,")
      |> mes("it seems to be easier said than done.^000000")
      |> close()
    else
      ctx
      |> mes("^3355FFI might have talent in")
      |> mes(
        "acting which hasn't been discovered yet. I thought, 'If I dress up, I should perform as the 'White Dryad...'^000000"
      )
      |> close()
    end
  end

  defp reflect_on_comfort(ctx) do
    ctx
    |> mes("^3355FFUnlike other cherry trees,")
    |> mes("this tree has a strong fragrance.")
    |> mes("I just fell into a relaxed")
    |> mes("mood. The fragrance eased")
    |> mes("my burdens and I felt")
    |> mes("very comfortable.^000000")
    |> next()
    |> mes("^3355FFIt was just for a few moments")
    |> mes("but I could forget the")
    |> mes("burdens of life. I wish to")
    |> mes("come back again and")
    |> mes("sit under this tree...^000000")
    |> close()
  end

  defp reflect_on_dread(ctx) do
    ctx
    |> mes("^3355FFThis strong fragrance")
    |> mes("is making me dizzy. Not like")
    |> mes("other cherry trees, this tree's")
    |> mes("shimmering white petals")
    |> mes("felt strange.^000000")
    |> next()
    |> mes("^3355FFIt feels as if my soul is")
    |> mes("being drained if I stay here")
    |> mes("longer. After a glimpse of")
    |> mes("the cherry tree, I thought to")
    |> mes("myself, 'I must get out of here quickly.'^000000")
    |> close()
  end

  defp inspect_tree(ctx) do
    ctx
    |> mes("^3355FFThere was a cherry tree")
    |> mes("on the hill. It doesn't look")
    |> mes("like the other trees.")
    |> mes("This tree seems to have")
    |> mes("a long history...^000000")
    |> next()
    |> mes("^3355FFAre there any people")
    |> mes("who live here? I took")
    |> mes("a look around and found")
    |> mes("someone down the hill.")
    |> mes("I better ask her about this tree.^000000")
    |> close()
  end
end
