defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.MjolnirSeal.Tialfi do
  @moduledoc """
  Tialfi dreams of Thor's hammer and starts and rewards the Mjolnir Seal quest.

  ## Behavior

  - Refuses to talk to a player who is carrying too many items.
  - Before the Mjolnir seal phase opens he only senses a strange force; once the seal is
    broken he waits to see Thor's thunder.
  - From base level 70 he tells his dream and asks the player to seek the Dwarven
    Blacksmiths, sending them to his sister Roskva with one of two random visiting orders.
  - Resets the Dwarves' progress when one of them was insulted.
  - Once all four Dwarves are met he releases the fourth seal, announcing it, and offers a
    family heirloom for 50 Rough Oridecon and 50 Rough Elunium: a weapon for the player's
    class, or a random one for a friend.

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
  - The original checked `BaseJob == Job_Hunter` twice, so the Rapture Rose (gift 13) was
    never chosen by class; the second check is `BaseJob == Job_Dancer`, the only second class
    missing from the list.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "prontera", x: 124, y: 297, dir: 3, sprite: 706, name: "Tialfi", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @heirlooms %{
    1 => 1471,
    2 => 1526,
    3 => 1231,
    4 => 1367,
    5 => 1722,
    6 => 1230,
    7 => 1141,
    8 => 1813,
    9 => 1557,
    10 => 1235,
    11 => 1227,
    12 => 1913,
    13 => 1963
  }

  @impl true
  def on_talk(ctx) do
    if checkweight(ctx, [{1301, 3}]) == 0 do
      ctx |> mes("- You are carrying too many items! -") |> close()
    else
      talk(ctx)
    end
  end

  defp talk(ctx) do
    cond do
      get_server_var(ctx, "God3", 0) < get_server_temp_var(ctx, "god_check1", 0) ->
        ctx
        |> cutin("god_tialpi01", 2)
        |> mes("[Tialfi]")
        |> mes("Hmmm...")
        |> mes("I can feel a strange force growing stronger and stronger, somewhere in Midgard.")
        |> next()
        |> mes("[Tialfi]")
        |> mes("Can you feel it?")
        |> mes("Something must be")
        |> mes("going on!")
        |> farewell()

      get_char_var(ctx, :god_mjo_0, 0) == 11 ->
        ctx
        |> cutin("god_tialpi01", 2)
        |> mes("[Tialfi]")
        |> mes(
          "I'm waiting for the day when I'll finally get to see Thor's thunder for myself. I believe that one of these days, my dream will become reality."
        )
        |> farewell()

      all_dwarves_met?(ctx) ->
        dwarves_met(ctx)

      dwarf_insulted?(ctx) ->
        ctx
        |> mes("[Tialfi]")
        |> mes("Hmm...")
        |> mes("The Dwarven Blacksmiths")
        |> mes("must be upset at you for")
        |> mes("some reason.")
        |> next()
        |> mes("[Tialfi]")
        |> mes("Remember my sister's")
        |> mes("suggestion and speak to")
        |> mes("them with great courtesy.")
        |> mes("Carefully choose words")
        |> mes("of respect lest they")
        |> mes("be insulted.")
        |> next()
        |> set_char_var(:god_mjo_1, 0)
        |> set_char_var(:god_mjo_2, 0)
        |> set_char_var(:god_mjo_3, 0)
        |> set_char_var(:god_mjo_4, 0)
        |> mes("[Tialfi]")
        |> mes("You should be okay now.")
        |> mes(
          "By this time, they've probably forgotten the insult. But make sure you speak to my sister for advice first."
        )
        |> farewell()

      get_char_var(ctx, :god_mjo_0, 0) == 2 or get_char_var(ctx, :god_mjo_0, 0) == 1 ->
        ctx
        |> cutin("god_tialpi01", 2)
        |> mes("[Tialfi]")
        |> mes("Sorry for the trouble.")
        |> mes("I wish you good luck")
        |> mes("in finding the Dwarves!")
        |> mes("Just... Don't insult them!")
        |> farewell()

      get_char_var(ctx, :god_mjo_0, 0) == 0 ->
        offer_quest(ctx)

      true ->
        ctx
        |> cutin("god_tialpi01", 2)
        |> mes("[Tialfi]")
        |> mes("I believe in you.")
        |> mes("Just be courageous!")
        |> farewell()
    end
  end

  defp all_dwarves_met?(ctx) do
    get_char_var(ctx, :god_mjo_1, 0) == 2 and get_char_var(ctx, :god_mjo_2, 0) == 2 and
      get_char_var(ctx, :god_mjo_3, 0) == 2 and get_char_var(ctx, :god_mjo_4, 0) == 2
  end

  defp dwarf_insulted?(ctx) do
    get_char_var(ctx, :god_mjo_1, 0) == 3 or get_char_var(ctx, :god_mjo_2, 0) == 3 or
      get_char_var(ctx, :god_mjo_3, 0) == 3 or get_char_var(ctx, :god_mjo_4, 0) == 3
  end

  defp farewell(ctx), do: ctx |> close2() |> cutin("god_tialpi01", 255)

  defp strange_energy(ctx) do
    ctx
    |> mes("[Tialfi]")
    |> mes("I sense a strange energy growing more powerful somewhere on this continent...")
    |> next()
    |> mes("[Tialfi]")
    |> mes("Can you feel it?")
    |> mes("Something must be going on!")
    |> next()
    |> mes("[Tialfi]")
    |> mes(
      "I think we'd better wait and see what's happening. Someone will deliver the news to us. Though, I am unsure of whether or not it will be good news or bad..."
    )
  end

  defp dwarves_met(ctx) do
    cond do
      get_char_var(ctx, :god_mjo_0, 0) == 10 ->
        if count_item(ctx, 756) > 49 and count_item(ctx, 757) > 49 do
          trade_ores(ctx)
        else
          ctx
          |> cutin("god_tialpi01", 2)
          |> mes("[Tialfi]")
          |> mes("I need")
          |> mes("50 Rough Oridecon")
          |> mes("and 50 Rough Elunium.")
          |> next()
          |> mes("[Tialfi]")
          |> mes(
            "I don't have much time, so go ahead and continue on your journeys if you can't bring those to me."
          )
          |> farewell()
        end

      get_server_var(ctx, "God4", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        ctx |> strange_energy() |> farewell()

      true ->
        release_seal(ctx)
    end
  end

  defp release_seal(ctx) do
    ctx = set_server_var(ctx, "God4", get_server_var(ctx, "God4", 0) + 1)

    ctx
    |> announce_seal(get_server_var(ctx, "God4", 0))
    |> set_char_var(:god_mjo_0, 10)
    |> mes("[Tialfi]")
    |> mes(
      "You've met the four Dwarven Blacksmiths. I've heard that they rarely speak to humans. So you must be special if you were able to talk to them."
    )
    |> next()
    |> mes("[Tialfi]")
    |> mes(
      "Do you think that my dream will come true? Do you believe Thor's Mjolnir will appear before the eyes of humans? I'm afraid great change will come to this world."
    )
    |> next()
    |> mes("[Tialfi]")
    |> mes(
      "Thank you for going through such trouble on my behalf. I wish to give you one of my family treasures as a token of my gratitude."
    )
    |> next()
    |> mes("[Tialfi]")
    |> mes(
      "However, I hope you understand that my family would grow suspicious if one of the treasures were to just go missing."
    )
    |> next()
    |> mes("[Tialfi]")
    |> mes(
      "Hmm, however, I don't think they'll complain if I exchanged one of the treasures for something else. Let me think..."
    )
    |> next()
    |> mes("[Tialfi]")
    |> mes("I should be able to give you")
    |> mes(
      "one of our family heirlooms if you can bring be 50 Rough Oridecons and 50 Rough Eluniums."
    )
    |> next()
    |> mes("[Tialfi]")
    |> mes(
      "You don't have to do that if you don't want to. But it seems our family heirlooms would be more useful to an adventurer such as yourself..."
    )
    |> farewell()
  end

  defp announce_seal(ctx, seal) do
    check2 = get_server_temp_var(ctx, "god_check2", 0)

    cond do
      seal == get_server_temp_var(ctx, "god_check1", 0) ->
        announce(ctx, "The 4th seal of [Mjolnir] has appeared.", 0)

      seal != check2 ->
        ctx

      get_server_var(ctx, "God2", 0) == check2 and get_server_var(ctx, "God3", 0) == check2 and
          get_server_var(ctx, "God1", 0) == check2 ->
        announce(
          ctx,
          "Four seals have been released at the same time with the seal of [Mjolnir].",
          0
        )

      true ->
        announce(ctx, "The 4th seal of [Mjolnir] has been released.", 0)
    end
  end

  defp trade_ores(ctx) do
    gift = gift_for_job(Rathena.job_id(base_job(ctx)))

    {ctx, choice} =
      ctx
      |> cutin("god_tialpi01", 2)
      |> mes("[Tialfi]")
      |> mes("You came back!")
      |> mes(
        "In exchange for the ores that you have brought me, I will give you one of my family treasures."
      )
      |> next()
      |> mes("[Tialfi]")
      |> mes(
        "You have two options in choosing a treasure. You can have a treasure that will be useful to yourself, or something that may suit one of your friends."
      )
      |> next()
      |> mes("[Tialfi]")
      |> mes("So which treasure")
      |> mes("would you like to have?")
      |> next()
      |> select(["An item that I can use.", "An item that my friend can use."])

    case choice do
      1 ->
        ctx
        |> mes("[Tialfi]")
        |> mes("I see...")
        |> mes("Give me a moment")
        |> mes("to find a suitable")
        |> mes("item for you.")
        |> hand_over(gift)

      2 ->
        gift = Enum.random(1..13)

        ctx
        |> mes("[Tialfi]")
        |> mes("I see...")
        |> mes("Give me a moment")
        |> mes("to find a suitable")
        |> mes("item for your friend.")
        |> hand_over(gift)

      _ ->
        ctx
    end
  end

  defp gift_for_job(job) do
    cond do
      job == Rathena.job_id(:knight) -> 1
      job == Rathena.job_id(:priest) -> 2
      job == Rathena.job_id(:wizard) -> 3
      job == Rathena.job_id(:blacksmith) -> 4
      job == Rathena.job_id(:hunter) -> 5
      job == Rathena.job_id(:assassin) -> 6
      job == Rathena.job_id(:crusader) -> 7
      job == Rathena.job_id(:monk) -> 8
      job == Rathena.job_id(:sage) -> 9
      job == Rathena.job_id(:alchemist) -> 10
      job == Rathena.job_id(:rogue) -> 11
      job == Rathena.job_id(:bard) -> 12
      job == Rathena.job_id(:dancer) -> 13
      true -> Enum.random(1..13)
    end
  end

  defp hand_over(ctx, gift) do
    ctx =
      ctx
      |> next()
      |> mes("[Tialfi]")
      |> mes("Okay, let's see...")
      |> mes("I seem to recall that I put it somewhere around... Hmm.")
      |> mes("It must be around--Ah!")
      |> mes("Here we are~")
      |> next()
      |> delitem(756, 50)
      |> delitem(757, 50)
      |> set_char_var(:god_mjo_0, 11)

    case Map.fetch(@heirlooms, gift) do
      {:ok, item} ->
        ctx
        |> give_item(item, 1)
        |> cutin("god_tialpi01", 2)
        |> mes("[Tialfi]")
        |> mes(
          "Once again, I thank you for the trouble you've gone through on my behalf. I'm unsure of how this works, but I hope it will be useful to you. From what I know, I believe this is a rare item."
        )
        |> next()
        |> mes("[Tialfi]")
        |> mes(
          "I'll be waiting for the day when I'll see Thor's thunder for myself. I believe that the dream I've had will come true, one of these days."
        )
        |> farewell()

      :error ->
        ctx |> mes("Unknown error occurred.") |> farewell()
    end
  end

  defp offer_quest(ctx) do
    cond do
      get_server_var(ctx, "God4", 0) >= get_server_temp_var(ctx, "god_check2", 0) ->
        ctx
        |> cutin("god_tialpi01", 2)
        |> strange_energy()
        |> close()
        |> cutin("", 255)

      base_level(ctx) < 70 ->
        ctx
        |> cutin("god_tialpi02", 2)
        |> mes("[Tialfi]")
        |> mes(
          "One of my ancestors supposedly was a servant of Thor. Still, I find it difficult to believe."
        )
        |> next()
        |> mes("[Tialfi]")
        |> mes(
          "If the gods have all these powers, how could a mere human be of any real assistance?"
        )
        |> farewell()

      true ->
        tell_dream(ctx)
    end
  end

  defp tell_dream(ctx) do
    {ctx, choice} =
      ctx
      |> cutin("god_tialpi01", 2)
      |> mes("[Tialfi]")
      |> mes(
        "Last night, I had the most amazing dream where I was the servant of Thor, god of thunder."
      )
      |> next()
      |> mes("[Tialfi]")
      |> mes("In this dream, I traveled")
      |> mes(
        "with Thor to Jotunnheim, land of giants. During our journey, he told me many interesting stories about gods and heroes."
      )
      |> next()
      |> mes("[Tialfi]")
      |> mes("Of course, I can't remember everything clearly, but it was truly fantastic.")
      |> next()
      |> mes("[Tialfi]")
      |> mes(
        "For some reason, I can vividly recall what Thor told me about his weapon, Mjolnir. Mjolnir is a Dwarven masterpiece."
      )
      |> next()
      |> mes("[Tialfi]")
      |> mes(
        "Thor told me that Dwarves are extremely talented artisans, and their works are supreme. So as"
      )
      |> mes("I was thinking about my dream,")
      |> mes("I remembered...")
      |> next()
      |> mes("[Tialfi]")
      |> mes("There is a mountain that")
      |> mes("has the same name as Thor's")
      |> mes("weapon. Surely, the two have")
      |> mes("some relation to each other.")
      |> next()
      |> mes("[Tialfi]")
      |> mes(
        "I've also recently heard a rumor that Dwarven Blacksmiths also reside on Mount Mjolnir."
      )
      |> mes(
        "I understand the mountain is dangerous, and that I'm in no position to ask such a thing..."
      )
      |> next()
      |> mes("[Tialfi]")
      |> mes(
        "I can't help wanting to know for myself whether or not there is truth to my dream. Is it possible for Mjolnir to resurface?"
      )
      |> next()
      |> mes("[Tialfi]")
      |> mes(
        "If you don't mind, I'd like to ask you to explore this mountain and search for these Dwarven Blacksmiths."
      )
      |> next()
      |> select(["No.", "Okay."])

    case choice do
      1 ->
        ctx
        |> cutin("god_tialpi02", 2)
        |> mes("[Tialfi]")
        |> mes("I see. But I still appreciate that you took the time to listen to me.")
        |> mes("Hopefully someday I'll learn the truth about my dreams and about Mjolnir itself.")
        |> farewell()

      2 ->
        ctx
        |> cutin("god_tialpi01", 2)
        |> mes("[Tialfi]")
        |> mes("Thank you,")
        |> mes("thank you so much!")
        |> mes(
          "Even though it won't be easy, I have faith that if the Dwarven Blacksmiths do exist, you'll be able to find them."
        )
        |> next()
        |> mes("[Tialfi]")
        |> mes(
          "Oh, and please speak to my sister Roskva first. She is outside the North Entrance of Prontera."
        )
        |> next()
        |> mes("[Tialfi]")
        |> mes("I'm sure that she can")
        |> mes("give you useful information if you're fortunate enough to encounter the Dwarves.")
        |> next()
        |> set_char_var(:god_mjo_0, Enum.random(1..2))
        |> mes("[Tialfi]")
        |> mes(
          "I'm truly lucky to meet such an adventurer like yourself. I wish you the best of luck."
        )
        |> farewell()

      _ ->
        ctx
    end
  end
end
