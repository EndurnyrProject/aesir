defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGeffen.Blacksmith do
  @moduledoc """
  A veteran Blacksmith in Geffen who forges the Welding Mask.

  ## Behavior

  - Explains the Welding Mask and offers to make one for 50 Steel and 2,000 zeny.
  - With at least 50 Steel and 2,000 zeny, takes both and gives a Welding Mask; otherwise
    reminds the player what he needs.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Samuray22
    - Lupus
    - Silent
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "geffen_in", x: 144, y: 166, dir: 4, sprite: 63, name: "Blacksmith", scope: :shared}
    ]

  @steel 999
  @welding_mask 2292

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Blacksmith]")
      |> mes(
        "You've never heard of me? Why, I'm the Veteran Blacksmith of this land. I've spent 30 years in this hot and bloody hellfire, bending steel to my iron will!"
      )
      |> next()
      |> mes("[Blacksmith]")
      |> mes("But...")
      |> mes(
        "I am growing older and my prowess begins to fade with age. So I've invented something for young, hot, upcoming Blacksmiths, in hopes that they too will master my craft..."
      )
      |> next()
      |> select(["What is it?", "..."])

    case choice do
      1 -> presents_the_mask(ctx)
      2 -> awed_silence(ctx)
      _ -> ctx
    end
  end

  defp presents_the_mask(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Blacksmith]")
      |> mes(
        "We Blacksmiths must always manipulate steel under extreme heat, and the hot air and melted metals are more than most people can stand."
      )
      |> next()
      |> mes("[Blacksmith]")
      |> mes("For the sake of our craft, our beautiful, yet masculine faces are put at risk...")
      |> next()
      |> mes("[Blacksmith]")
      |> mes(
        "But with this wonder of technology, there's no need to worry! Behold, the ^3355FFWelding Mask^000000 !!"
      )
      |> next()
      |> mes("[Blacksmith]")
      |> mes(
        "It works by covering your face with a fat metal plate. Truly, it's an item that everyone should want! If not yourself, it'd be a good idea to give this to a friend who is studying smithing."
      )
      |> next()
      |> mes("[Blacksmith]")
      |> mes(
        "So how about it ? If you give me ^2244FF50 Steel^000000 and ^4422FFonly 2000 Zeny^000000, I will make it for you right away~!!"
      )
      |> next()
      |> select(["Hm... Not bad. Alright.", "How does it work again?"])

    case choice do
      1 -> makes_the_mask(ctx)
      2 -> explains_the_mask(ctx)
      _ -> ctx
    end
  end

  defp makes_the_mask(ctx) do
    if count_item(ctx, @steel) > 49 and zeny(ctx) > 1999 do
      ctx
      |> mes("[Blacksmith]")
      |> mes(
        "Ah, I see that you appreciate a Blacksmith's work! Alright, I'll do it right away !!"
      )
      |> next()
      |> delitem(@steel, 50)
      |> pay_zeny(2000)
      |> give_item(@welding_mask, 1)
      |> mes("[Blacksmith]")
      |> mes("Hahaha~! Make good use of that!")
      |> close()
    else
      ctx
      |> mes("[Blacksmith]")
      |> mes("Hmmm...")
      |> mes("You do not have the items I require.")
      |> next()
      |> mes("[Blacksmith]")
      |> mes(
        "A common Blacksmith would interpret this as a sign of disrepect, but I will forgive you. Just don't forget what I need if you want me to make you this mask."
      )
      |> close()
    end
  end

  defp explains_the_mask(ctx) do
    ctx
    |> mes("[Blacksmith]")
    |> mes(
      "The ^3355FFWelding Mask^000000 protects your face by covering it with a fat metal plate. This invention is the result of 30 years of endless toil at the hammer and anvil."
    )
    |> close()
  end

  defp awed_silence(ctx) do
    ctx
    |> mes("[Blacksmith]")
    |> mes("Ah...!")
    |> mes(
      "I guess this is the first time you've met a Blacksmith as great as me, and you're just speechless with awe. Please, take your time and speak up when you are ready."
    )
    |> next()
    |> mes("^3355FFThis guy seems")
    |> mes("a little full")
    |> mes("of himself.^000000")
    |> close()
  end
end
