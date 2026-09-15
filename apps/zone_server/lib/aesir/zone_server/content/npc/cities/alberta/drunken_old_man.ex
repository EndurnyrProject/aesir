defmodule Aesir.ZoneServer.Content.Npc.Cities.Alberta.DrunkenOldMan do
  @moduledoc """
  Recounts Deagle's days aboard the pirate ship Going Mary.

  ## Behavior

  - Offers alternate stories about the ship and its formidable captain.
  - Dismisses visitors who leave him alone.

  ## Credits

  - Original from rAthena, authors and Contributors
    - DZeroX

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 131,
        y: 139,
        dir: 2,
        sprite: 54,
        name: "Drunken Old Man",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Deagle]")
      |> mes("^666666*Hiccup*^000000")
      |> mes("Wh-what are you")
      |> mes("staring at? Get lost!!")
      |> next()
      |> select(["Say nothing.", "Leave him alone."])

    case choice do
      1 -> share_sailing_story(ctx)
      2 -> dismiss_visitor(ctx)
      _ -> ctx
    end
  end

  defp share_sailing_story(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Deagle]")
      |> mes(
        "Hahahaha ^666666*hiccup*^000000... You've got some nerve. I may look worthless now, but I used to be a sailor on the 'Going Mary.'"
      )
      |> next()
      |> select(["Never heard of it.", "Really? No kidding!"])

    case choice do
      1 -> explain_going_mary(ctx)
      2 -> praise_the_captain(ctx)
      _ -> dismiss_visitor(ctx)
    end
  end

  defp explain_going_mary(ctx) do
    ctx
    |> mes("[Deagle]")
    |> mes(
      "Never heard of it?! Everybody knows th'notorious pirate ship 'Going Mary!' ^666666*Hiccup~*^000000"
    )
    |> next()
    |> mes("[Deagle]")
    |> mes(
      "Ah~ The ol'days. If only... If only we hadn't run into that STORM...^666666*hiccup*^000000"
    )
    |> next()
    |> mes("[Deagle]")
    |> mes(
      "AH~ Captain. I miss our cap'n more than anything... No foe survived before cap'n's sword."
    )
    |> close()
  end

  defp praise_the_captain(ctx) do
    ctx
    |> mes("[Deagle]")
    |> mes(
      "That's right! NOBODY meshes with the crew of the 'Going Mary!' And nobody can beat out cap'n in a sword fight!"
    )
    |> next()
    |> mes("[Deagle]")
    |> mes(
      "CAPTAIN~!!! ^666666*HICCUP~*^000000 He would swing his sword like this, then... THEN!!"
    )
    |> next()
    |> mes("[Deagle]")
    |> mes(
      "The bastard the captain was fighting, and anyone of his friends near him, were surrounded in flame!"
    )
    |> next()
    |> mes("[Deagle]")
    |> mes(
      "Man, that sword must have had some sort of mysterious power, or the captain was just that good...!"
    )
    |> next()
    |> mes("[Deagle]")
    |> mes(
      "Phew~~ ^666666*Sob* *Sob...*^000000 God, I miss everyone! Now I'm depressed! Please, go away now."
    )
    |> close()
  end

  defp dismiss_visitor(ctx) do
    ctx
    |> mes("[Deagle]")
    |> mes("That's right!")
    |> mes("Go AWAY~")
    |> close()
  end
end
