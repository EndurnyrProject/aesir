defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.CityHallOfficer do
  @moduledoc """
  Handles document requests at Luoyang's city hall.

  ## Behavior

  - Accepts a bribe to expedite eligible document requests.
  - Gives visitors advice according to their quest progress.

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
        map: "lou_in02",
        x: 210,
        y: 47,
        dir: 0,
        sprite: 825,
        name: "City Hall Officer",
        scope: :shared,
        unique_name: "City Hall Officer#lou"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :ch_par, 0)

    cond do
      progress < 5 -> greet_tourist(ctx)
      progress < 9 -> offer_document(ctx)
      progress < 11 -> warn_tourist(ctx)
      progress < 15 -> ctx |> upstairs_reminder() |> welcome()
      progress == 15 -> completed(ctx)
      true -> welcome(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp greet_tourist(ctx) do
    ctx
    |> mes("[Jin Chiyuan]")
    |> mes("^666666*Yawn~*^000000")
    |> mes("Gosh, this hot weather is such")
    |> mes("a pain. Oh? You look like a tourist. Are you enjoying your stay?")
    |> next()
    |> mes("[Jin Chiyuan]")
    |> mes(
      "Although we've been having bad weather recently, there are many good places to visit in Luoyang."
    )
    |> mes("I hope you have a good time.")
    |> close()
  end

  defp offer_document(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jin Chiyuan]")
      |> mes("Hm? A Midgardian?")
      |> mes("Now, how may I help you?")
      |> next()
      |> select(["I need a document.", "I just dropped by."])

    if choice == 1, do: request_document(ctx), else: warn_tourist(ctx)
  end

  defp request_document(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jin Chiyuan]")
      |> mes("Ah, you do?")
      |> mes(
        "Unfortunately, there are many people waiting in line to procure government forms, so it will take"
      )
      |> mes("a while to handle your request.")
      |> next()
      |> mes("[Jin Chiyuan]")
      |> mes("^333333*Whispers*")
      |> mes(
        "Well, there is a way that you can, shall we say, expediate our processing of your request...^000000"
      )
      |> next()
      |> select(["Huh? Come again?", "A little zeny to cut the red tape, eh?"])

    if choice == 1 do
      ctx
      |> mes("[Jin Chiyuan]")
      |> mes("^666666*Ahem!*^000000 Nothing.")
      |> mes(
        "Nothing of importance. Now, I'm very busy, so if you would go fill the application over there..."
      )
      |> close()
    else
      accept_bribe(ctx)
    end
  end

  defp accept_bribe(ctx) do
    {ctx, amount} = input(ctx, :int)
    ctx = set_local(ctx, :input, amount)
    amount = get_local(ctx, :input, 0)

    cond do
      amount < 10_000 ->
        ctx
        |> mes("[Jin Chiyuan]")
        |> mes("Good lord,")
        |> mes("what are you thinking?")
        |> mes("What am I, a beggar?!")
        |> mes("That's a poor excuse")
        |> mes("for a bribe!")
        |> reject_bribe()

      zeny(ctx) > amount ->
        ctx
        |> mes("[Jin Chiyuan]")
        |> mes("What...?!")
        |> mes("That's not what I meant,")
        |> mes("but if you insist on donating to our government...")
        |> next()
        |> mes("[Jin Chiyuan]")
        |> mes("^666666*Whispers*^000000")
        |> mes(
          "^333333When you go up stairs, another officer will give you the document you want.^000000 ^666666*Ahem*^000000 Luoyang thanks you!"
        )
        |> pay_zeny(amount)
        |> advance_quest()
        |> close()

      true ->
        ctx
        |> mes("[Jin Chiyuan]")
        |> mes(
          "Good lord, what are you thinking? What am I, a beggar?! That's a poor excuse for a bribe!"
        )
        |> reject_bribe()
    end
  end

  defp advance_quest(ctx) do
    case get_char_var(ctx, :ch_par, 0) do
      5 -> ctx |> set_char_var(:ch_par, 11) |> changequest(11_046, 11_051)
      6 -> ctx |> set_char_var(:ch_par, 12) |> changequest(11_047, 11_052)
      7 -> ctx |> set_char_var(:ch_par, 13) |> changequest(11_048, 11_053)
      8 -> ctx |> set_char_var(:ch_par, 14) |> changequest(11_049, 11_054)
      _ -> ctx
    end
  end

  defp reject_bribe(ctx) do
    ctx
    |> next()
    |> mes("[Jin Chiyuan]")
    |> mes("I mean...")
    |> mes(
      "How dare you bribe an officer of the law! I hope other outsiders are not like you! Please leave immediately!"
    )
    |> emotion(:hng)
    |> close()
  end

  defp warn_tourist(ctx) do
    ctx
    |> mes("[Jin Chiyuan]")
    |> mes("Oh well...")
    |> mes(
      "Let me tell you that this is not a good time for tourists. I hope you don't wander into places you're"
    )
    |> mes("not supposed to be.")
    |> next()
    |> mes("[Jin Chiyuan]")
    |> mes("Quite frankly,")
    |> mes("it's a dangerous climate for curiosity right now. Please,")
    |> mes("be careful.")
    |> close()
  end

  defp upstairs_reminder(ctx) do
    ctx
    |> mes("[Jin Chiyuan]")
    |> mes(
      "Haven't you met the officer I told you about? I've contacted him about the matter, so you may meet him upstairs."
    )
    |> next()
    |> mes("[Jin Chiyuan]")
    |> mes("Hahahaha...")
    |> mes("Take care,")
    |> mes("Midgardian.")
  end

  defp completed(ctx) do
    ctx
    |> mes("[Jin Chiyuan]")
    |> mes("Ah~")
    |> mes("You met him,")
    |> mes("didn't you?")
    |> mes("Hahaha...")
    |> mes("Enjoy your stay")
    |> mes("in Luoyang!")
    |> emotion(:smile)
    |> close()
  end

  defp welcome(ctx) do
    ctx
    |> mes("[Jin Chiyuan]")
    |> mes("Welcome.")
    |> mes("How may I help you?")
    |> next()
    |> mes("[Jin Chiyuan]")
    |> mes("If you have nothing to ask of me, please leave. This place is not")
    |> mes("a playground for adventurers.")
    |> emotion(:hng)
    |> close()
  end
end
