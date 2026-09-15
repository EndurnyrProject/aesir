defmodule Aesir.ZoneServer.Content.Npc.Cities.Amatsu.Veterinarian do
  @moduledoc """
  Tells a sinister rumor about corpses beneath Amatsu's legendary cherry tree.

  ## Behavior

  - Marks the tree conversation as the veterinarian's perspective.
  - Responds differently to horror and disbelief before trailing off ominously.

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
        x: 274,
        y: 178,
        dir: 7,
        sprite: 735,
        name: "Veterinarian",
        scope: :shared,
        unique_name: "Veterinarian#ama"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> set_char_var(:jap_tree, 4)
      |> mes("[Sakura Seiichi]")
      |> mes("Ah... I'm not a weirdo so")
      |> mes("don't panic. I'm just an ordinary")
      |> mes("veterinarian. My job is curing")
      |> mes("sick animals.")
      |> mes(" ")
      |> next()
      |> mes("[Sakura Seiichi]")
      |> mes("By the way... Do you know?")
      |> mes("The story about the cherry tree")
      |> mes("on the hill...I guess you haven't heard about it...")
      |> next()
      |> mes("[Sakura Seiichi]")
      |> mes("That tree has a secret of")
      |> mes("keeping its beauty and whiteness.")
      |> mes("The secret is...")
      |> mes("There are corpses buried under...")
      |> mes("that tree...")
      |> next()
      |> select(["How horrible!", "You have got to be kidding."])

    if choice == 1 do
      entertain_horror(ctx)
    else
      answer_disbelief(ctx)
    end
  end

  defp entertain_horror(ctx) do
    ctx
    |> mes("[Sakura Seiichi]")
    |> mes("Kuhuhu... They could be...")
    |> mes("By the way, do you want")
    |> mes("make a bet on it...?")
    |> next()
    |> emotion(:think)
    |> mes("[Sakura Seiichi]")
    |> mes("If I..........")
    |> mes("............")
    |> mes(".........")
    |> next()
    |> mes("^3355FFHis voice was getting lower")
    |> mes("and lower as the wind blew.")
    |> mes(
      "Finally, I couldn't even hear his voice. I can't even recall what he was trying to tell me...^000000"
    )
    |> close()
  end

  defp answer_disbelief(ctx) do
    ctx
    |> mes("[Sakura Seiichi]")
    |> mes(
      "I can't help it if you think that way. But one day, you too could be buried underneath..."
    )
    |> next()
    |> emotion(:think)
    |> mes("[Sakura Seiichi]")
    |> mes("Haha... Hahaha.....")
    |> mes("...............")
    |> mes("...........")
    |> next()
    |> mes("^3355FFHis laugh was getting lower")
    |> mes("and lower as the wind blew.")
    |> mes(
      "Finally, I couldn't even hear anything. I can't even recall what he was trying to tell me...^000000"
    )
    |> close()
  end
end
