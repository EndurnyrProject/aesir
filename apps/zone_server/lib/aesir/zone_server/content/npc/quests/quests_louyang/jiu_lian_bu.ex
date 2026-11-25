defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.JiuLianBu do
  @moduledoc """
  Recruits adventurers to steal soup from a Luoyang restaurant.

  ## Behavior

  - Restores legacy quest progress and directs the player to steal broth.
  - Judges stolen soup and takes successful helpers to his secluded spot.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_fild01",
        x: 195,
        y: 177,
        dir: 5,
        sprite: 819,
        name: "Jiu Lian Bu",
        scope: :shared,
        unique_name: "Jiu Lian Bu#1-1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    ctx = restore_progress(ctx)

    case get_char_var(ctx, :ch_tre, 0) do
      0 -> introduction(ctx)
      1 -> awaiting_soup(ctx)
      2 -> wrong_soup(ctx)
      3 -> right_soup(ctx)
      progress when progress in 4..5 -> revisit(ctx)
      _ -> dismiss(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp restore_progress(ctx) do
    ctx
    |> restore_legacy(:QL_ACCEPTSOUP, 1)
    |> restore_legacy(:QL_GOTDRAGONSOUP, 2)
    |> restore_legacy(:QL_GOTFAKESOUP, 3)
    |> restore_legacy(:QL_SOUPQUEST, 4)
    |> restore_legacy(:QL_SOUP2, 5)
    |> set_char_var(:QL_ACCEPTSOUP, 0)
    |> set_char_var(:QL_GOTDRAGONSOUP, 0)
    |> set_char_var(:QL_GOTFAKESOUP, 0)
    |> set_char_var(:QL_SOUPQUEST, 0)
    |> set_char_var(:QL_SOUP2, 0)
  end

  defp restore_legacy(ctx, variable, progress) do
    if Rathena.truthy?(get_char_var(ctx, variable, 0)) do
      set_char_var(ctx, :ch_tre, progress)
    else
      ctx
    end
  end

  defp introduction(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jiu Lian Bu]")
      |> mes("Hey~")
      |> mes("What's up?")
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes(
        "I don't like hanging around too many people, so I came here. Listening to this stream really puts my mind at ease."
      )
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes("No offense, but I'm upset")
      |> mes(
        "at the sheer number of tourists coming over to Luoyang. Sure, I can understand that our town is attractive and has beautiful sights."
      )
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes("But I just can't stand crowds of people. People gather like sheep")
      |> mes("to any place that they hear is popular, and that really bugs me!")
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes("Speaking of which, there's even")
      |> mes("a place in Luoyang that's just like that. Man, I hate that restaurant!")
      |> next()
      |> select(["What restaurant?", "Ignore him."])

    if choice == 1, do: explain_plan(ctx), else: ignore(ctx)
  end

  defp explain_plan(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jiu Lian Bu]")
      |> mes("West of Luoyang, there's")
      |> mes(
        "a restaurant built on a pond. It's been around for a long time, selling food for ridiculous prices!"
      )
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes("Oh sure, the food and flavors")
      |> mes(
        "there have a long history, but I don't think that justifies how they charge their patrons!"
      )
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes("As a young man")
      |> mes("who loves his town,")
      |> mes("I can't let them manipulate my people like that!")
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes(
        "But everyone here already knows who I am, so I can't do anything! I've already had one too many, shall we say, 'incidents' with the people living here already."
      )
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes(
        "I've been caught for tagging walls, shoplifting, scamming, stealing a few girlfriends... So yeah, I'm not exactly known as a sterling citizen."
      )
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes(
        "Say, wait a minute. The local people around here aren't too familiar with you. Hmmm..."
      )
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes("Would you sneak into that restaurant and steal the")
      |> mes("^3131FFDragon Soup Broth^000000 for me?")
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes("The Dragon Soup Broth is the backbone for the restaurant")
      |> mes("owner's secret recipe.")
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes(
        "But they've been cheating their customers by watering that broth down and selling it for a ridiculous price! Serves them right if their secrets were stolen!"
      )
      |> next()
      |> mes("[Jiu Lian Bu]")
      |> mes("If you can steal some of the broth, I'll pay you back. So whaddya say?")
      |> next()
      |> select(["I'll do it!", "No, stealing is wrong."])

    if choice == 1, do: accept(ctx), else: refuse(ctx)
  end

  defp accept(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("Grrrrreat!")
    |> mes("I knew you'd")
    |> mes("see things my way!")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes(
      "Okay, the restaurant is at the West side of Luoyang. But you gotta be careful. The workers there watch over that broth like freakin' hawks!"
    )
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes(
      "When you finally steal the broth, make sure you bring it without spilling any. Okay? Good luck~"
    )
    |> set_char_var(:ch_tre, 1)
    |> close()
  end

  defp refuse(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("Stealing?")
    |> mes("You may have")
    |> mes("a point there.")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes(
      "But then, that restaurant has been doing that to their customers for years! So, technically, we'd just be stealing back."
    )
    |> close()
  end

  defp ignore(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes(
      "That joint isn't even that great. I mean, it's so obvious that they rip off their customers! Dragon Soup?! More like... Dragon Crap Soup!"
    )
    |> close()
  end

  defp awaiting_soup(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("Huh...?")
    |> mes("Whoa, I thought you were on your way to the restaurant. You better get a move on.")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes("Alright then, pal. Make sure the guys who work there don't catch you. Good luck~")
    |> close()
  end

  defp wrong_soup(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("Wow! You made it!")
    |> mes("Let me see...")
    |> taste_soup()
    |> mes("[Jiu Lian Bu]")
    |> mes("Ohhhh man....")
    |> mes("This is soooo not Dragon Soup Broth. Sorry, but would you go")
    |> mes("and try to get it again?")
    |> set_char_var(:ch_tre, 1)
    |> close()
  end

  defp right_soup(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("Wow!")
    |> mes("You made it!")
    |> mes("Let me see...")
    |> taste_soup()
    |> mes("[Jiu Lian Bu]")
    |> mes("Ooooh. Ooh yeah.")
    |> mes("This is the stuff.")
    |> mes("Muhahahahahaha~!")
    |> mes("This'll put the chef")
    |> mes("in agony for a while!")
    |> next()
    |> mes("[Jiu Lian Bu]")
    |> mes(
      "Good job, chum! Heh heh heh, because you risked your neck for me, I'm gonna show you an awesome place! Just follow me~"
    )
    |> set_char_var(:ch_tre, 4)
    |> close2()
    |> warp("lou_fild01", 180, 170)
  end

  defp taste_soup(ctx) do
    ctx
    |> next()
    |> mes("^3355FFJiu Lian Bu takes")
    |> mes("a hearty sip of the")
    |> mes("broth you've managed")
    |> mes("to steal for him.^000000")
    |> next()
  end

  defp revisit(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jiu Lian Bu]")
      |> mes("Hey~")
      |> mes("So how ya been, ya smooth criminal? You wanna visit that place again?")
      |> next()
      |> select(["Sure, let's go~", "Nah, maybe next time."])

    if choice == 1, do: travel(ctx), else: decline_visit(ctx)
  end

  defp travel(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("Alright~")
    |> mes("Let's get")
    |> mes("a groove on.")
    |> close2()
    |> warp("lou_fild01", 180, 170)
  end

  defp decline_visit(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("Not in the mood, eh?")
    |> mes("No prob. But feel free")
    |> mes("to come see me whenever")
    |> mes("you want.")
    |> close()
  end

  defp dismiss(ctx) do
    ctx
    |> mes("[Jiu Lian Bu]")
    |> mes("Wha...?")
    |> mes("Hey, who are you? If you don't got anything to say to me, then get lost!")
    |> close()
  end
end
