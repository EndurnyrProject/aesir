defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MjolnirSeal.DwarfBlacksmith do
  @moduledoc """
  Austri, one of the Dwarf Blacksmith brothers on Mount Mjolnir whose trust the player must earn
  in the Mjolnir Seal quest.

  ## Behavior

  - Outside the Mjolnir seal phase he only speaks of his visions of the Fenrir-Wolf.
  - Before the quest starts he enjoys the day; at the later stages he hints at the quest's
    remaining tasks.
  - In each round of the brothers' visits he refuses players who were rude to any brother, and
    rebukes and marks as rude a player who greets him casually out of turn.
  - Visited in turn, he asks for a sign of respect for blacksmiths; brought a Hammer of
    Blacksmith, he tells the tale of Mjolnir, and answering every question attentively marks
    him as done while a careless answer marks the player as rude.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Lupus
    - Samuray22
    - L0ne_W0lf
    - Zephyrus
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mjolnir_11",
        x: 149,
        y: 247,
        dir: 5,
        sprite: 826,
        name: "Dwarf Blacksmith",
        scope: :shared,
        unique_name: "Dwarf Blacksmith#east"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_server_var(ctx, "God3", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        fenrir_visions(ctx)

      get_server_var(ctx, "God4", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        fenrir_visions(ctx)

      true ->
        talk(ctx, get_char_var(ctx, :god_mjo_0, 0))
    end
  end

  defp talk(ctx, 11) do
    ctx
    |> mes("[Austri]")
    |> mes(
      "When my people finally retrieve the memories of their past, we will be able to grant the power of the gods to humans."
    )
    |> next()
    |> mes("[Austri]")
    |> mes("I believe that")
    |> mes("time is coming...")
    |> close()
  end

  defp talk(ctx, 10) do
    ctx
    |> mes("[Austri]")
    |> mes(
      "Hm? I sense that you were asked to do a favor for that human. If I were you, I'd finish that task as soon as I could. Somehow, that human's fate, as well as that of the Dwarves, are intertwined..."
    )
    |> close()
  end

  defp talk(ctx, 1) do
    cond do
      rude_to_any_brother?(ctx) ->
        refuse(ctx)

      get_char_var(ctx, :god_mjo_1, 0) == 2 ->
        nothing_to_say(ctx, "What...?")

      Enum.any?([:god_mjo_2, :god_mjo_3, :god_mjo_4], &(get_char_var(ctx, &1, 0) != 0)) ->
        case ask(ctx, ["Hm...?", "Why have you", "come to me, human?"], ["Nothing.", "Hey, 'sup!"]) do
          {ctx, 1} ->
            silence(ctx)

          {ctx, 2} ->
            ctx
            |> set_char_var(:god_mjo_1, 3)
            |> mes("[Austri]")
            |> mes("What...?!")
            |> mes("Do not greet the")
            |> mes("Dwarves lightly,")
            |> mes("mortal!")
            |> close()

          {ctx, _} ->
            ctx
        end

      get_char_var(ctx, :god_mjo_1, 0) == 1 ->
        hammer_check(ctx, :god_mjo_1)

      get_char_var(ctx, :god_mjo_1, 0) == 0 ->
        introduction(ctx, :god_mjo_1, ["What has made", "you come to me?"])

      true ->
        sleeping(ctx)
    end
  end

  defp talk(ctx, 2) do
    cond do
      rude_to_any_brother?(ctx) ->
        refuse(ctx)

      get_char_var(ctx, :god_mjo_4, 0) == 2 ->
        nothing_to_say(ctx, "What is it...?")

      Enum.any?([:god_mjo_1, :god_mjo_2, :god_mjo_3], &(get_char_var(ctx, &1, 0) in [0, 1])) ->
        case ask(ctx, ["What made you come to me?"], ["Nothing.", "Hey, sup!"]) do
          {ctx, 1} ->
            silence(ctx)

          {ctx, 2} ->
            ctx
            |> set_char_var(:god_mjo_4, 3)
            |> mes("[Austri]")
            |> mes("What?!")
            |> mes("Leave immediately and go study your english properly!")
            |> close()

          {ctx, _} ->
            ctx
        end

      get_char_var(ctx, :god_mjo_4, 0) == 1 ->
        hammer_check(ctx, :god_mjo_4)

      get_char_var(ctx, :god_mjo_4, 0) == 0 ->
        introduction(ctx, :god_mjo_4, ["What made you come to me?"])

      true ->
        sleeping(ctx)
    end
  end

  defp talk(ctx, 0) do
    ctx
    |> mes("[Austri]")
    |> mes("Ah...")
    |> mes("It feels like today's going to be a great day.")
    |> next()
    |> mes("[Austri]")
    |> mes(
      "I've got the warm sun, fresh forest air, and my hammer and anvil are at the ready. It's a perfect day for smithing!"
    )
    |> close()
  end

  defp talk(ctx, _stage), do: sleeping(ctx)

  defp rude_to_any_brother?(ctx) do
    Enum.any?(
      [:god_mjo_1, :god_mjo_2, :god_mjo_3, :god_mjo_4],
      &(get_char_var(ctx, &1, 0) == 3)
    )
  end

  defp ask(ctx, lines, options) do
    ctx
    |> mes("[Austri]")
    |> mes_lines(lines)
    |> next()
    |> select(options)
  end

  defp mes_lines(ctx, lines), do: Enum.reduce(lines, ctx, &mes(&2, &1))

  defp introduction(ctx, quest_var, lines) do
    case ask(ctx, lines, ["Nothing.", "Excuse me, sir."]) do
      {ctx, 1} ->
        silence(ctx)

      {ctx, 2} ->
        ctx
        |> mes("[Austri]")
        |> mes("A respectable blacksmith cherishes his tools and crafts with diligence and care.")
        |> next()
        |> mes("[Austri]")
        |> mes(
          "When it comes to humans, I believe the ones who can appreciate my line of work are the only ones worth talking to."
        )
        |> next()
        |> set_char_var(quest_var, 1)
        |> mes("[Austri]")
        |> mes(
          "Every good blacksmith knows the value of a good hammer. If you can understand that, I shall consider speaking with you."
        )
        |> next()
        |> mes("[Austri]")
        |> mes("Now go, human.")
        |> mes("I wish you safety")
        |> mes("in your travels.")
        |> close()

      {ctx, _} ->
        ctx
    end
  end

  defp hammer_check(ctx, quest_var) do
    case ask(ctx, ["What has made", "you come to me?"], ["Nothing.", "Excuse me, sir."]) do
      {ctx, 1} ->
        silence(ctx)

      {ctx, 2} ->
        if count_item(ctx, 1005) > 0 do
          ctx
          |> mes("[Austri]")
          |> mes(
            "Ah, I see that the entire human race is not worthy of scorn. Unlike many of your kind, I see that you respect your elders."
          )
          |> next()
          |> lecture(quest_var)
        else
          ctx
          |> mes("[Austri]")
          |> mes("You don't seem to")
          |> mes("understand. If you")
          |> mes(
            "wish to prove to me that you understand blacksmiths, you should bring something related to my work!"
          )
          |> close()
        end

      {ctx, _} ->
        ctx
    end
  end

  defp lecture(ctx, quest_var) do
    case lecture_step(ctx, get_local(ctx, :talk_to, 0), quest_var) do
      {:ended, ctx} ->
        ctx

      {:asked, ctx} ->
        if get_local(ctx, :talk_not, 0) == 1 do
          ctx
          |> set_char_var(quest_var, 3)
          |> mes("[Austri]")
          |> mes("Grrr...!")
          |> mes("You're not listening, are you?! What a waste of my time!")
          |> next()
          |> mes("[Austri]")
          |> mes(
            "This is why I don't want to associate with humans. They always shut me out when I'm talking!"
          )
          |> close()
        else
          ctx
          |> set_local(:talk_to, get_local(ctx, :talk_to, 0) + 1)
          |> lecture(quest_var)
        end
    end
  end

  defp lecture_step(ctx, 0, _quest_var) do
    ctx
    |> ask(["So what did", "want to ask", "me about?"], ["...", "About Mjolnir."])
    |> listed_answer(2, 2)
  end

  defp lecture_step(ctx, 1, _quest_var) do
    ctx
    |> mes("[Austri]")
    |> mes("Mjolnir...?")
    |> mes("Thor's legendary weapon?")
    |> mes(
      "The hammer than can shake the earth and tear the sky asunder? Out of all of legendary weapons, Mjolnir is perhaps greatest."
    )
    |> next()
    |> mes("[Austri]")
    |> mes(
      "As a matter of fact, it was forged by my ancestor. Mjolnir was the perfect weapon, except for one minor flaw."
    )
    |> next()
    |> mes("[Austri]")
    |> mes("The hilt of Mjolnir was forged shorter than intended. Are you still listening to me?")
    |> next()
    |> select(["...", "Yes, sir!", "Huh?"])
    |> answer(2)
  end

  defp lecture_step(ctx, 2, quest_var) do
    result =
      ctx
      |> mes("[Austri]")
      |> mes(
        "One day, Loki came to our village and showed off his treasures. He boasted that we couldn't possibly create something to surpass their quality."
      )
      |> next()
      |> mes("[Austri]")
      |> mes("Frankly his treasures were")
      |> mes(
        "made by another Dwarf tribe, but we couldn't tolerate his insult. So my ancestors created three treasures of their own."
      )
      |> next()
      |> select(["...", "Boooring!", "Oh, wow."])

    case quest_var do
      :god_mjo_1 -> answer(result, 3)
      :god_mjo_4 -> listed_answer(result, 3, 3)
    end
  end

  defp lecture_step(ctx, 3, _quest_var) do
    ctx
    |> mes("[Austri]")
    |> mes("Of the three treasures my ancestors created, Mjolnir was the last and greatest.")
    |> next()
    |> mes("[Austri]")
    |> mes(
      "However, while it was created, a strange fly bit my ancestor on the hand. Because of this interruption, Mjolnir's hilt is a little flawed."
    )
    |> next()
    |> mes("[Austri]")
    |> mes(
      "It's very sad. Although Mjolnir is the greatest weapon ever, it was very close to being the epitome of craftsmanship."
    )
    |> next()
    |> select(["...", "Epito--what?", "Yes sir, I agree."])
    |> answer(3)
  end

  defp lecture_step(ctx, 4, _quest_var) do
    ctx
    |> mes("[Austri]")
    |> mes(
      "Despite this minor flaw, Mjolnir is still considered the greatest of legendary weapons."
    )
    |> next()
    |> mes("[Austri]")
    |> mes(
      "Mjolnir was the trusted weapon Thor wielded on the battlefield, and every giant feared its power."
    )
    |> next()
    |> mes("[Austri]")
    |> mes(
      "I must say, a Blacksmith's greatest pride comes when he creates the weapon and armor that can be considered his life's work."
    )
    |> next()
    |> select(["...", "I agree, sir!", "Um, yeah."])
    |> answer(2)
  end

  defp lecture_step(ctx, 5, _quest_var) do
    ctx
    |> mes("[Austri]")
    |> mes(
      "The reason this mountain is called Mount Mjolnir is because it was actually created by the hammer."
    )
    |> next()
    |> mes("[Austri]")
    |> mes(
      "In a battle against demons a thousand years ago, Thor struck the earth with Mjolnir. The impact caused the ground to rise, creating this mountain."
    )
    |> next()
    |> mes("[Austri]")
    |> mes("You can imagine just")
    |> mes("how powerful Mjolnir is.")
    |> mes(
      "However, humans can never hope to see or even wield Mjolnir. Only a god can handle that kind of force."
    )
    |> next()
    |> select(["...", "Wah wah wah~!", "Ah, I understand sir!"])
    |> answer(3)
  end

  defp lecture_step(ctx, 6, _quest_var) do
    ctx
    |> mes("[Austri]")
    |> mes(
      "Hmm... But perhaps an ambitious dwarf can forge something similar to Mjolnir so that it can actually be used by humans. It would have less power, but it'd be perfectly crafted."
    )
    |> next()
    |> mes("[Austri]")
    |> mes("Yes, it's possible to create")
    |> mes("a Mjolnir suited to humans. Still, it wouldn't be very easy.")
    |> next()
    |> select(["...", "Yes, sir!", "Yeah, whatever."])
    |> answer(2)
  end

  defp lecture_step(ctx, 7, _quest_var) do
    ctx
    |> mes("[Austri]")
    |> mes(
      "Well, I happened to speak much longer than I intended. But I hope you learned what you wished to"
    )
    |> mes("know about Mjolnir.")
    |> next()
    |> mes("[Austri]")
    |> mes("I feel that a great change is coming. I do not know what kind")
    |> mes("of effect it will have on our world, but something important will happen...")
    |> next()
    |> mes("[Austri]")
    |> mes("Perhaps only the gods can be")
    |> mes(
      "sure as to what the future will bring. In any case, we must prepare ourselves for what will happen."
    )
    |> next()
    |> select(["...", "Yes?", "Yes, sir!"])
    |> answer(3)
  end

  defp lecture_step(ctx, 8, quest_var) do
    ctx =
      ctx
      |> set_char_var(quest_var, 2)
      |> mes("[Austri]")
      |> mes("Alright then...")
      |> farewell(quest_var)
      |> close()

    {:ended, ctx}
  end

  defp farewell(ctx, :god_mjo_1) do
    ctx
    |> mes("If you wish to learn more, you should speak to my brothers.")
    |> mes("Take care, human.")
  end

  defp farewell(ctx, :god_mjo_4) do
    ctx
    |> mes("Take care of")
    |> mes("yourself, human.")
  end

  defp answer({ctx, correct}, correct), do: {:asked, ctx}
  defp answer({ctx, _choice}, _correct), do: {:asked, set_local(ctx, :talk_not, 1)}

  defp listed_answer({ctx, correct}, correct, _count), do: {:asked, ctx}

  defp listed_answer({ctx, choice}, _correct, count) when choice in 1..count//1,
    do: {:asked, set_local(ctx, :talk_not, 1)}

  defp listed_answer({ctx, _choice}, _correct, _count), do: {:ended, ctx}

  defp fenrir_visions(ctx) do
    ctx
    |> mes("[Austri]")
    |> mes(
      "Something is happening somewhere on this continent. You might not believe me, but I keep getting visions of the Fenrir-Wolf."
    )
    |> close()
  end

  defp refuse(ctx) do
    ctx
    |> mes("[Austri]")
    |> mes("What is it?! I refuse to speak to human as rude and contemptible")
    |> mes("as you! Now, get out of my sight!")
    |> close()
  end

  defp nothing_to_say(ctx, opening) do
    ctx
    |> mes("[Austri]")
    |> mes(opening)
    |> mes("I have nothing")
    |> mes("to say to you.")
    |> close()
  end

  defp silence(ctx), do: ctx |> mes("[Austri]") |> mes("...") |> close()

  defp sleeping(ctx), do: ctx |> mes("[Austri]") |> mes("Zzzz Zzzz...") |> close()
end
