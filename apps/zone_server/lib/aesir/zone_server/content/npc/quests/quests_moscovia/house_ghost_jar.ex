defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.HouseGhostJar do
  @moduledoc """
  A rattling jar hiding the bored house ghost Baba Yaga wants silenced.

  ## Behavior

  - At stage 31, kicking the jar releases three bugs, hides the jar for three minutes (a killed
    bug brings it back) and advances the quest to stage 32.
  - At stage 32 the ghost begs for company and asks for a card game (stage 33).
  - At stage 33 the ghost plays a best-of-five card guessing game; three right guesses advance
    the quest to stage 34.
  - At stage 34 the ghost accepts a Milk as a present, if carried, and the quest moves to stage 45.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_dun02",
        x: 57,
        y: 220,
        dir: 0,
        sprite: 111,
        name: "House Ghost Jar",
        scope: :shared,
        unique_name: "House Ghost Jar#rus43"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @self "House Ghost Jar#rus43"
  @mob_dead_event "House Ghost Jar#rus43::OnMyMobDead"
  @cards ["Poring", "Angeling", "Ghostring"]
  @guardian_promise "I promise I wil be quiet now. I will be the acting guardian for this house!"

  @impl true
  def on_event("OnDisable", ctx), do: ctx |> initnpctimer() |> disablenpc(@self)

  def on_event("OnTimer180000", ctx) do
    ctx
    |> stopnpctimer()
    |> killmonster("mosk_dun02", @mob_dead_event)
    |> enablenpc(@self)
  end

  def on_event("OnMyMobDead", ctx), do: enablenpc(ctx, @self)

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :rhea_rus_main, 0) do
      31 -> kick_jar(ctx)
      32 -> ghost_pleads(ctx)
      33 -> card_game(ctx)
      34 -> milk_present(ctx)
      45 -> guardian_thanks(ctx)
      _ -> ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp kick_jar(ctx) do
    ctx =
      ctx
      |> player_says("... Is it in here..? Hey, hey...")
      |> next()
      |> mes("- You tap the jar -")
      |> mes("- with your hand -")
      |> specialeffect(:sightrasher)

    ctx
    |> emotion(:huk, playerattached(ctx))
    |> next()
    |> mes("- A voice laughs in the jar as -")
    |> mes("- it shakes from right to left -")
    |> next()
    |> player_says("You! No more games! Come out of there!")
    |> specialeffect(:hit2)
    |> next()
    |> mes("- You kick the jar -")
    |> mes("- it rolls to the floor -")
    |> mes("- as bugs come out!! -")
    |> set_char_var(:rhea_rus_main, 32)
    |> summon_bug(1054, 58, "Thief Bug Male")
    |> summon_bug(1305, 59, "Ancient Worm")
    |> summon_bug(1054, 60, "Thief Bug Male")
    |> donpcevent("House Ghost Jar#rus43::OnDisable")
    |> close()
  end

  defp summon_bug(ctx, mob_id, x, name) do
    summon_mob(ctx,
      mob_id: mob_id,
      map: "mosk_dun02",
      at: {x, 220},
      name: name,
      event: @mob_dead_event
    )
  end

  defp ghost_pleads(ctx) do
    {ctx, choice} =
      ctx
      |> player_says("Ehh.. you, what are you doing!!")
      |> next()
      |> mes("- As you plan to kick the jar -")
      |> mes("- again, something scared -")
      |> mes("- utters in a shaky voice -")
      |> specialeffect(:curseattack)
      |> next()
      |> mes("[House Ghost]")
      |> mes("No! Please stop it! I was wrong!")
      |> next()
      |> mes("[House Ghost]")
      |> mes(
        "I have been bored. After dying, I've had nothing to do and no friends to play with.."
      )
      |> next()
      |> mes("[House Ghost]")
      |> mes("When I was alive, I always stayed still, but now it's too boring...")
      |> next()
      |> mes("[House Ghost]")
      |> mes("I can't even drink my favorite milk... Being a ghost is too inconvenient.")
      |> next()
      |> select(["Can I play with you?", "So what can I do for you?"])

    reply =
      if choice == 1,
        do: "Ehhh, are you sure?",
        else: "Hmm, can you do something for me? It won't take much time."

    ctx
    |> mes("[House Ghost]")
    |> mes(reply)
    |> next()
    |> mes("[House Ghost]")
    |> mes(
      "What about a card game? I was good at those games! Ah, where are my cards? Wait here! I'll find them!"
    )
    |> set_char_var(:rhea_rus_main, 33)
    |> close()
  end

  defp card_game(ctx) do
    player = char_name(ctx, 0)

    ctx =
      ctx
      |> mes("[House Ghost]")
      |> mes("Hehe, what about a card game? I have an Angeling, Ghostring and a Poring Card.")
      |> mes("All you have to do is just guess which card I pick up!")
      |> next()
      |> mes("[House Ghost]")
      |> mes("Let's play best out of 5. So if you win 3 games, I promise to stay quiet!")
      |> next()
      |> named_says(player, "Ok! It will be fun. Let's do it.")
      |> next()

    {ctx, score} = play_rounds(ctx, player, 0, 0)

    if score == 3 do
      ctx
      |> mes("[House Ghost]")
      |> mes("You are better than I thought.")
      |> set_char_var(:rhea_rus_main, 34)
      |> close()
    else
      ctx
      |> named_says(player, "I was not thinking correctly! Let's do it again!")
      |> next()
      |> mes("[House Ghost]")
      |> mes("Huhu, ok. Let's do it again?")
      |> close()
    end
  end

  defp play_rounds(ctx, player, turn, score, win \\ "")

  defp play_rounds(ctx, player, turn, score, win) when turn < 5 and score < 3 do
    ctx =
      ctx
      |> mes("[House Ghost]")
      |> mes("Ok, first let me shuffle these cards around.")
      |> mes("Ready!")
      |> emotion(:blabla)
      |> next()
      |> mes("[House Ghost]")
      |> mes("One!")
      |> specialeffect(:hit1)
      |> next()
      |> mes("[House Ghost]")
      |> mes("One! Two!")
      |> specialeffect(:hit2)
      |> next()
      |> mes("[House Ghost]")
      |> mes("One! Two! Three!")
      |> specialeffect(:hit3)
      |> next()
      |> mes("[House Ghost]")
      |> mes("Ok! I will pick one of them up!")
      |> specialeffect(:steal)
      |> next()
      |> mes("[House Ghost]")
      |> mes("Ok! I will pick one of them up!")
      |> mes("What is this card?")
      |> cutin("sorry.bmp", 4)
      |> next()

    card = Enum.random(1..3)
    {ctx, choice} = select(ctx, @cards)

    {ctx, win} =
      ctx
      |> named_says(player, "Hmmm, I think it is the #{Enum.at(@cards, choice - 1, "")} Card!")
      |> next()
      |> mes("[House Ghost]")
      |> mes("Ok, time to find out!")
      |> mes("One! Two! Three!!")
      |> next()
      |> cutin("", 255)
      |> reveal(card, win)

    ctx = emotion(ctx, :surprise)

    {ctx, score} =
      if card == choice do
        ctx =
          ctx
          |> emotion(:aha, playerattached(ctx))
          |> next()
          |> mes("[House Ghost]")
          |> mes("You got it right.")
          |> mes(win)

        {ctx, score + 1}
      else
        ctx =
          ctx
          |> emotion(:huk, playerattached(ctx))
          |> next()
          |> mes("[House Ghost]")
          |> mes("Huuu...")
          |> mes("Better luck next time!")

        {ctx, score}
      end

    ctx
    |> cutin("", 255)
    |> next()
    |> play_rounds(player, turn + 1, score, win)
  end

  defp play_rounds(ctx, _player, _turn, score, _win), do: {ctx, score}

  defp reveal(ctx, 1, _win),
    do: {cutin(ctx, "????Ä«??", 4), "You are good. Can you do it next time?"}

  defp reveal(ctx, 2, _win),
    do: {cutin(ctx, "??????Ä«??", 4), "You are pretty good at this. Ok, but can you do it again?"}

  defp reveal(ctx, 3, _win),
    do:
      {cutin(ctx, "????Æ®??Ä«??", 4), "You are pretty good at this. Ok, but can you do it again?"}

  defp reveal(ctx, _card, win), do: {ctx, win}

  defp milk_present(ctx) do
    player = char_name(ctx, 0)

    ctx =
      ctx
      |> mes("[House Ghost]")
      |> mes(
        "Ah, it was fun. It has been a long time since I've been able to play a game like that."
      )
      |> next()
      |> mes("[House Ghost]")
      |> mes("As promised, I will be quiet now. Thank you for playing with me.")
      |> next()
      |> named_says(player, "Oh and by the way, I have a present for you!")
      |> next()

    if Rathena.truthy?(count_item(ctx, 519)) do
      ctx
      |> named_says(player, "You said you like milk. Here, take this.")
      |> next()
      |> mes("[House Ghost]")
      |> mes("Ah, wow!! Can I have this?")
      |> next()
      |> mes("[House Ghost]")
      |> mes("Thank you so much!!")
      |> mes(@guardian_promise)
      |> next()
      |> mes("[House Ghost]")
      |> mes("I will never forget your kindness of entertaining me.")
      |> set_char_var(:rhea_rus_main, 45)
      |> close()
    else
      ctx
      |> named_says(player, "You said you like milk. Here, take.. Eh?")
      |> next()
      |> named_says(player, "W, where is this? Wait here. I will bring it soon!!")
      |> close()
    end
  end

  defp guardian_thanks(ctx) do
    ctx
    |> mes("[House Ghost]")
    |> mes("Thank you so much!!")
    |> mes(@guardian_promise)
    |> next()
    |> mes("[House Ghost]")
    |> mes("I will never forget your kindness of entertaining me.")
    |> close()
  end

  defp player_says(ctx, line), do: named_says(ctx, char_name(ctx, 0), line)

  defp named_says(ctx, name, line), do: ctx |> mes("[#{name}]") |> mes(line)
end
