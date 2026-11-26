defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsVeins.ThinFacedBard do
  @moduledoc """
  Guides the player through the final encounter with the fugitive bard.

  ## Behavior

  - Requests reports from three contacts and stages the bard’s arrest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Toms
    - Euphy
    - Joseph
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "morocc",
        x: 297,
        y: 154,
        dir: 0,
        sprite: 51,
        name: "Thin-Faced Bard",
        scope: :shared,
        unique_name: "Thin-Faced Bard#sch"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFWait a second!")
        |> mes("Right now, you're carrying")
        |> mes("too many things with you.")
        |> mes("Please come back after")
        |> mes("using the Kafra Service")
        |> mes("to store some of your items.^000000")
        |> close()

      get_char_var(ctx, :que_sch, 0) < 19 ->
        ctx |> mes("[????]") |> mes("............") |> close()

      true ->
        speak(ctx, get_char_var(ctx, :que_sch, 0))
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp speak(ctx, 19) do
    {ctx, _} =
      ctx
      |> mes("[Vitre]")
      |> mes("Thanks for your help.")
      |> mes("This country's government")
      |> mes("should know better than to")
      |> mes("put a good man like me in jail.")
      |> mes("Listen, I'm a fugitive now.")
      |> mes("Do you think you can help me?")
      |> next()
      |> select(["Sure.", "I may as well..."])

    ctx
    |> mes("[Vitre]")
    |> mes("I just need you to talk")
    |> mes("to a few people, and let")
    |> mes("me know what they said.")
    |> mes("I'd do it myself, but you")
    |> mes("understand that I've got")
    |> mes("to keep a low profile.")
    |> next()
    |> mes("[Vitre]")
    |> mes("Please meet these people")
    |> mes("in the order that I tell you.")
    |> mes("I've sent messengers to let")
    |> mes("them know of your arrival,")
    |> mes("but I had to send them out")
    |> mes("at different times... Anyway...")
    |> next()
    |> mes("[Vitre]")
    |> mes("First, go to Prontera")
    |> mes("and talk to Chada. Second,")
    |> mes("go to Geffen and speak to")
    |> mes("Ghez. Lastly, please go to")
    |> mes("Comodo and meet Nosdan.")
    |> next()
    |> mes("[Vitre]")
    |> mes("Each one of them will")
    |> mes("sing you a song. Listen")
    |> mes("carefully, and sing me their")
    |> mes("songs when you come back.")
    |> mes("Thanks, you have no idea how")
    |> mes("much I appreciate your help.")
    |> set_char_var(:que_sch, 20)
    |> close()
  end

  defp speak(ctx, 20) do
    ctx
    |> mes("[Vitre]")
    |> mes("Chada is probably near")
    |> mes("the middle of Prontera.")
    |> mes("The messenger I sent to")
    |> mes("him should have reached")
    |> mes("him by now, so he should")
    |> mes("be expecting your arrival.")
    |> close()
  end

  defp speak(ctx, 21) do
    ctx
    |> mes("[Vitre]")
    |> mes("Ah, now you've got to")
    |> mes("talk to Ghez. He should")
    |> mes("be in Northeast Geffen")
    |> mes("somewhere. Hopefully")
    |> mes("you won't have too much")
    |> mes("trouble finding him.")
    |> close()
  end

  defp speak(ctx, 22) do
    ctx
    |> mes("[Vitre]")
    |> mes("Trying to find Nosdan?")
    |> mes("I think he's probably in the")
    |> mes("Northern Cave in Comodo.")
    |> mes("Please talk to him, and let")
    |> mes("me know about his song.")
    |> close()
  end

  defp speak(ctx, 23) do
    {ctx, choice} =
      ctx
      |> mes("[Vitre]")
      |> mes("Welcome back.")
      |> mes("So did you listen")
      |> mes("to all of their songs?")
      |> next()
      |> select(["Yes", "No"])

    if choice == 1 do
      ctx =
        ctx
        |> mes("[Vitre]")
        |> mes("Perfect~ Here's a little")
        |> mes("something to show my")
        |> mes("gratitude. Hope you like it.")
        |> set_char_var(:que_sch, 24)
        |> give_item(603, 1)
        |> next()

      arrest(ctx)
    else
      ctx
      |> mes("[Vitre]")
      |> mes("Would you please hurry?")
      |> mes("Staying in one place like")
      |> mes("this makes me nervous...")
      |> mes("I should be on the move...")
      |> close()
    end
  end

  defp speak(ctx, 24), do: arrest(ctx)

  defp speak(ctx, _) do
    ctx
    |> mes("[Bard]")
    |> mes("Oh, uh...")
    |> mes("I'm not really Vitre.")
    |> mes("I'm just a lookalike that's")
    |> mes("been planted here in case")
    |> mes("his hoodlum buddies come")
    |> mes("here to find him. You know?")
    |> next()
    |> mes("[Bard]")
    |> mes("Yeah... This is a pretty")
    |> mes("dumb job. I mean, all I do")
    |> mes("is stand here, waiting for")
    |> mes("his spy friends. What are")
    |> mes("the odds of that happening?")
    |> close()
  end

  defp arrest(ctx) do
    ctx
    |> mes("[Vitre]")
    |> mes("Now, tell me, what")
    |> mes("exactly did they si--")
    |> next()
    |> mes("[????]")
    |> mes("Hold it!")
    |> next()
    |> enablenpc("????#sch1")
    |> enablenpc("????#sch2")
    |> enablenpc("????#sch3")
    |> mes("[Vitre]")
    |> mes("What? Wh-who the")
    |> mes("hell are you guys?!")
    |> next()
    |> mes("[????]")
    |> mes("Rune-Midgarts")
    |> mes("Secret Service!")
    |> mes("Vitre Bizlleta--")
    |> mes("you're under arrest")
    |> mes("for espionage!")
    |> next()
    |> mes("[Vitre]")
    |> mes("Again? Didn't you just")
    |> mes("arrest me just for being")
    |> mes("suspected of espionage?")
    |> mes("I think it's a little unfair")
    |> mes("to just capture me when")
    |> mes("you don't have any proof.")
    |> next()
    |> mes("[????]")
    |> mes("We just seized concrete")
    |> mes("evidence of your illegal")
    |> mes("activities. It's probably")
    |> mes("enough to imprison you")
    |> mes("for life. Happy now?")
    |> next()
    |> mes("[Vitre]")
    |> mes("You're bluffing.")
    |> next()
    |> mes("[????]")
    |> mes("You shouldn't have sent")
    |> mes("that unsuspecting adventurer")
    |> mes("to your news sources. We've")
    |> mes("taken them into custody")
    |> mes("Chada, Ghez, Nosdan.")
    |> mes("That's them, right?")
    |> next()
    |> mes("[Vitre]")
    |> mes("Nooooooooo!")
    |> next()
    |> mes("[Suden]")
    |> mes("Adventurer, thank you for")
    |> mes("your cooperation. I am")
    |> mes("Suden Griea, Secret Service")
    |> mes("agent. I'm sure you have")
    |> mes("a lot of questions, but ^FF0000Lasda")
    |> mes("Midar^000000 will answer them.")
    |> next()
    |> mes("[Suden]")
    |> mes("I'd explain here and now,")
    |> mes("but I better dispose of")
    |> mes("this trash with the rest of")
    |> mes("his scum buddies... in jail!")
    |> set_char_var(:que_sch, 25)
    |> close2()
    |> disablenpc("????#sch1")
    |> disablenpc("????#sch2")
    |> disablenpc("????#sch3")
  end
end
