defmodule Aesir.ZoneServer.Content.Npc.Quests.CounteragentMixture.Morgenstein do
  @moduledoc """
  Chemist Morgenstein, the obsessed Geffen alchemist who brews Counteragent and
  Mixture out of the solutions the player brings him.

  ## Behavior

  - Refuses to talk while the player carries too much weight to receive items.
  - When the player arrives on Aure Dupon's hint (`molgenstain` step 2), greets
    them, sets quest bit 4 of `MISC_QUEST`, clears `molgenstain` and explains his
    research.
  - Otherwise, explains the research again or offers a new solution: a Counteragent
    from Alcohol, Detrimindexta and an Empty Bottle plus 3000 zeny, or a Mixture
    from Alcohol, Karvodailnirol and an Empty Bottle plus 4000 zeny.
  - A brew is abandoned without spending anything when the ingredients or the zeny
    are missing, and re-checked after the brewing dialogue.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Komurka
    - L0ne_W0lf
    - Everade
    - Lupus
    - Darkchild
    - Nexon

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "geffen_in",
        x: 141,
        y: 140,
        dir: 3,
        sprite: 121,
        name: "Morgenstein",
        scope: :shared,
        unique_name: "Morgenstein#cm"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @alcohol 970
  @empty_bottle 713
  @detrimindexta 971
  @karvodailnirol 972

  @counteragent_recipe %{
    solution: @detrimindexta,
    product: 973,
    cost: 3_000,
    shortage: [
      "Heuheuheuheuh.... not enough... not enough.. Haah...Haah... Go..... get the rest of the materials!",
      "We'll postpone the fun until then... Heuheuheuheuheuh."
    ],
    synthesis: [
      "Ooooooooh...... heeheeheeheehee...... yes... like that...... yes... more... more........ heeheeheehee.",
      ".... Aaah.... ahah... ha....ahahooooooooohoh!"
    ]
  }

  @mixture_recipe %{
    solution: @karvodailnirol,
    product: 974,
    cost: 4_000,
    shortage: [
      "Hohohoho.... not enough... not enough... haah...haah... go..... go get the rest of the materials!!",
      "We'll have to postpone the fun for later... Hehehehe"
    ],
    synthesis: [
      "Ooooooooh... heehee...... yes... like that...... yes... more... more........ heeheeheehee",
      ".... Aaah.... ahah... ha....ahah...oooooooooooooooooh!!!...!!!!!!"
    ]
  }

  @out_of_materials "Hohohoho.... not enough... not enough... haah...haah... go..... go get the rest of the materials!!"

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if checkweight(ctx, [{1201, 1}]) == 0 do
      carrying_too_much(ctx)
    else
      talk(ctx)
    end
  end

  defp carrying_too_much(ctx) do
    ctx
    |> mes("- Wait a minute !! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please try again -")
    |> mes("- after you lose some weight. -")
    |> close()
  end

  defp talk(ctx) do
    cond do
      Rathena.truthy?(:erlang.band(get_char_var(ctx, :MISC_QUEST, 0), 4)) ->
        research_menu(ctx)

      get_char_var(ctx, :molgenstain, 0) == 2 ->
        first_meeting(ctx)

      true ->
        not_a_test_subject(ctx)
    end
  end

  defp research_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Chemist Morgenstein]")
      |> mes(".....")
      |> mes("Welcome.")
      |> mes("Hehehehe....")
      |> mes("Heeheeheeheehee....")
      |> next()
      |> select(["Ask about his research", "Ask him to make a new solution.", "Cancel"])

    case choice do
      1 -> research_lecture(ctx)
      2 -> make_solution(ctx)
      3 -> chuckle(ctx)
      _ -> ctx
    end
  end

  defp first_meeting(ctx) do
    {ctx, choice} =
      ctx
      |> set_char_var(:MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), 4))
      |> set_char_var(:molgenstain, 0)
      |> mes("[Chemist Morgenstein]")
      |> mes("Heeheeheehee.... welcome. Hehehehe.... heeheeheeheehee....")
      |> next()
      |> mes("[Chemist Morgenstein]")
      |> mes("Ah...?!")
      |> mes(
        "So sorry if I weirded you out. It's just... I haven't seen a living person in soooo long. So, er, what can I do for you??"
      )
      |> next()
      |> select(["Ask about his research.", "Cancel."])

    if choice == 1, do: welcome_lecture(ctx), else: close(ctx)
  end

  defp not_a_test_subject(ctx) do
    ctx
    |> mes("[Chemist Morgenstein]")
    |> mes("Heeheeheehee...")
    |> mes(
      "You're not here to be a test subject, are you? Probably not though. Not since my little 'accident.' Heeheeheeee~!"
    )
    |> close()
  end

  defp chuckle(ctx) do
    ctx
    |> mes("[Chemist Morgenstein]")
    |> mes("Heehee....heheheheh....")
    |> close()
  end

  defp research_lecture(ctx) do
    ctx
    |> research_intro()
    |> mes("[Chemist Morgenstein]")
    |> mes(
      "It can't melt everything yet, but I did find that you could combine things that you could never mix before with my invention. Heeheeheehee~!"
    )
    |> next()
    |> mes("[Chemist Morgenstein]")
    |> mes(
      "You can make a whole lot of things that you'd never would have imagined possible! I can make you a lot of new things you never would have imagined using this method... as long as you want it!!"
    )
    |> next()
    |> endorphins()
  end

  defp welcome_lecture(ctx) do
    ctx
    |> research_intro()
    |> mes("[Chemist Morgenstein]")
    |> mes(
      "It can't melt everything yet, but I did find that you could combine things that you could never mix before with my invention."
    )
    |> next()
    |> mes("[Chemist Morgenstein]")
    |> mes(
      "I can make you a lot of new things you never would have imagined using this method... as long as you want it!!"
    )
    |> next()
    |> endorphins()
  end

  defp research_intro(ctx) do
    ctx
    |> mes("[Chemist Morgenstein]")
    |> mes("Heeheeheeheee...")
    |> mes(
      "You must have heard the rumors about my research. Yes! But since you probably know already, I'll tell you without hiding, I mean, there's nothing to hide."
    )
    |> next()
    |> mes("[Chemist Morgenstein]")
    |> mes(
      "Actually, you can say my research is complete! Nothing's impossible for my genius! Bwahaha, it's just a matter of time!"
    )
    |> next()
    |> mes("[Chemist Morgenstein]")
    |> mes(
      "Are you still here? Right, you wanted to know about my research. It's actually very simple. I was just trying to invent a super liquid that can melt everything!"
    )
    |> next()
    |> mes("[Chemist Morgenstein]")
    |> mes(
      "Isn't it interesting? No matter how strong you are, you can't break apart stone or steel, but with my new liquid, you can melt those things, making them soft like puddy!"
    )
    |> next()
  end

  defp endorphins(ctx) do
    ctx
    |> mes("[Chemist Morgenstein]")
    |> mes(
      "The endorphins are rushing to my face at least 2.1 times faster than the usual rate! Ah! I'm so excited! I... I just can't hide it!"
    )
    |> close()
  end

  defp make_solution(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Chemist Morgenstein]")
      |> mes("So...")
      |> mes(
        "You want me to make something totally new, huh? Hehhehheh! I love your sense of scientific adventure!"
      )
      |> next()
      |> select(["Counteragent", "Mixture"])

    case choice do
      1 -> counteragent(ctx)
      2 -> mixture(ctx)
      _ -> ctx
    end
  end

  defp counteragent(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Chemist Morgenstein]")
      |> mes("Ooh...!")
      |> mes("You want to make a Counteragent? Hohohohoho, let's see what we'll need...")
      |> next()
      |> mes("[Chemist Morgenstein]")
      |> mes(
        "Oh, I remember, yes, Alcohol, and um, er, Detrimindexta and an Empty Bottle to put it it all in. Just these three items and 3000 zeny."
      )
      |> next()
      |> ready_to_brew()

    if choice == 1, do: brew(ctx, @counteragent_recipe), else: come_back(ctx)
  end

  defp mixture(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Chemist Morgenstein]")
      |> mes("Ooh...!")
      |> mes("You want to make a Mixture? Hohohohoho, let's see what we'll need...")
      |> next()
      |> mes("[Chemist Morgenstein]")
      |> mes(
        "Ooh, I remember now, yes, Alcohol, and um, er, Karvodailnirol and an empty bottle to put all of it in. Just these three items and 4000 zeny."
      )
      |> next()
      |> ready_to_brew()

    if choice == 1,
      do: brew(ctx, @mixture_recipe),
      else: come_back(ctx, ["Heh... heuheuheuheh...."])
  end

  defp ready_to_brew(ctx) do
    ctx
    |> mes("[Chemist Morgenstein]")
    |> mes("Bwahahahah!")
    |> mes("Oh, I just can't wait to make this! Are you ready to begin?")
    |> next()
    |> select(["Make", "Cancel"])
  end

  defp come_back(ctx, extra_lines \\ []) do
    ctx
    |> mes("[Chemist Morgenstein]")
    |> mes("Hee hee hee...!")
    |> mes("Come back when")
    |> mes("you're ready~")
    |> mes_lines(extra_lines)
    |> close()
  end

  defp brew(ctx, recipe) do
    if has_ingredients?(ctx, recipe) do
      ctx
      |> mes("[Chemist Morgenstein]")
      |> mes_lines(recipe.synthesis)
      |> next()
      |> finish_brew(recipe)
    else
      ctx
      |> mes("[Chemist Morgenstein]")
      |> mes_lines(recipe.shortage)
      |> close()
    end
  end

  defp finish_brew(ctx, recipe) do
    if has_ingredients?(ctx, recipe) do
      ctx
      |> delitem(@alcohol, 1)
      |> delitem(recipe.solution, 1)
      |> delitem(@empty_bottle, 1)
      |> pay_zeny(recipe.cost)
      |> give_item(recipe.product, 1)
      |> mes("[Chemist Morgenstein]")
      |> mes("Hee hee hee...")
      |> mes("Haaaaah......")
      |> mes("Oh? We're done already?!")
      |> close()
    else
      ctx
      |> mes("[Chemist Morgenstein]")
      |> mes(@out_of_materials)
      |> close()
    end
  end

  defp has_ingredients?(ctx, recipe) do
    Enum.all?([@alcohol, recipe.solution, @empty_bottle], &(count_item(ctx, &1) > 0)) and
      zeny(ctx) >= recipe.cost
  end

  defp mes_lines(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))
end
