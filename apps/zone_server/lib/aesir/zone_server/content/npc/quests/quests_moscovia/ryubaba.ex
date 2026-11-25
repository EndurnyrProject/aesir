defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.Ryubaba do
  @moduledoc """
  Ryubaba helps reveal the fate of her sister and the red ring.

  ## Behavior

  - Responds to the player's progress, clothing and gifts during the ring quest.
  - Reveals her sister's fate and offers to exchange the ring for the flute.

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
        map: "moscovia",
        x: 213,
        y: 216,
        dir: 3,
        sprite: 960,
        name: "Ryubaba",
        scope: :shared,
        unique_name: "Ryubaba#rus08"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 3500 ->
        ctx
        |> mes("[Ryubaba]")
        |> mes("What on earth do you have in your bag?")
        |> mes("Are you training for something?")
        |> close()

      get_char_var(ctx, :rhea_rus_main, 0) < 8 ->
        greeting(ctx)

      get_char_var(ctx, :rhea_rus_main, 0) == 8 ->
        ring_quest(ctx, get_char_var(ctx, :rhea_rus_ring, 0))

      true ->
        remorse(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ring_quest(ctx, ring) do
    cond do
      not Rathena.truthy?(ring) -> greeting(ctx)
      ring == 1 -> first_meeting(ctx)
      ring == 2 -> dismiss_player(ctx)
      ring == 3 -> offer_rose(ctx)
      ring == 4 -> ask_about_ring(ctx)
      ring > 4 and ring < 7 -> ring_story(ctx) |> close()
      ring == 7 -> confront_ryubaba(ctx)
      ring == 8 -> insist_on_truth(ctx)
      true -> remorse(ctx)
    end
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Ryubaba]")
    |> mes("Ah, how beautiful I am.")
    |> next()
    |> mes("[Ryubaba]")
    |> mes(
      "Mmm, you must be an adventurer? What would you say? Have you seen somebody more beautiful than me? I doubt it. How can you find anyone more beautiful than me?"
    )
    |> emotion(:smile)
    |> close()
  end

  defp remorse(ctx) do
    ctx
    |> mes("[Ryubaba]")
    |> mes("................................")
    |> mes("I was stupid...")
    |> next()
    |> mes("[Ryubaba]")
    |> mes("I have to repent for my sins and atone for them for the rest of my life.")
    |> close()
  end

  defp ring_story(ctx) do
    ctx
    |> mes("[Ryubaba]")
    |> mes("Ah, that ring... Yes, my father gave it to my baby sister, Mashenka.")
    |> mes("But, she went out to take a stroll and disappeared around the marsh.")
    |> next()
    |> mes(player_name(ctx))
    |> mes("Wait, your father told me that she died!")
    |> next()
    |> mes("[Ryubaba]")
    |> mes(
      "Right... Let me finish talking. We tried searching for her but we couldn't find her. She must have been wearing the ring when she disappeared around the marsh."
    )
  end

  defp reward_experience(ctx) do
    level = base_level(ctx)

    if Rathena.truthy?(checkre(ctx, 3)) do
      cond do
        level < 56 -> getexp(ctx, 470, 0)
        level < 61 -> getexp(ctx, 615, 0)
        level < 66 -> getexp(ctx, 750, 0)
        level < 71 -> getexp(ctx, 1_000, 0)
        level < 76 -> getexp(ctx, 1_500, 0)
        level < 81 -> getexp(ctx, 2_000, 0)
        level < 86 -> getexp(ctx, 4_500, 0)
        level < 91 -> getexp(ctx, 8_500, 0)
        level < 275 -> getexp(ctx, 30_000, 0)
        true -> ctx |> give_item(607, 1) |> getexp(30_000, 0)
      end
    else
      cond do
        level < 56 -> getexp(ctx, 4_700, 0)
        level < 61 -> getexp(ctx, 6_150, 0)
        level < 66 -> getexp(ctx, 10_605, 0)
        level < 71 -> getexp(ctx, 16_223, 0)
        level < 76 -> getexp(ctx, 41_227, 0)
        level < 81 -> getexp(ctx, 69_073, 0)
        level < 86 -> getexp(ctx, 85_102, 0)
        level < 91 -> getexp(ctx, 104_615, 0)
        level < 99 -> getexp(ctx, 222_035, 0)
        true -> give_item(ctx, 607, 1)
      end
    end
  end

  defp insist_on_truth(ctx) do
    ctx = ctx |> mes("[Ryubaba]") |> mes("You give it back to me!") |> next()

    ctx
    |> mes(player_name(ctx))
    |> mes("I have to let your father know the truth! He has to know what you have done!")
    |> next()
    |> mes("[Ryubaba]")
    |> mes("W, wait!!!")
    |> close2()
    |> warp("moscovia", 203, 80)
  end

  defp confront_ryubaba(ctx) do
    if getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 do
      ctx
      |> mes(player_name(ctx))
      |> mes("...Hmm, did I forget to wear something...?")
      |> close()
    else
      ctx =
        ctx
        |> mes("[Ryubaba]")
        |> mes("Ah, you come here again. What can I do for you?")
        |> next()

      ctx =
        ctx
        |> mes(player_name(ctx))
        |> mes("... Listen to this song.")
        |> next()

      if count_item(ctx, 7883) > 0 do
        ctx =
          ctx
          |> mes("- You play the flute -")
          |> next()
          |> mes("^ff0000Red ring that my father gave me^000000")
          |> mes("^ff0000Red ring that my father gave me^000000")
          |> mes("^ff0000The red ring enchanted^000000")
          |> mes("^ff0000For the loveliest daughter^000000")
          |> next()
          |> mes("^ff0000Red ring bringing up jealousy^000000")
          |> mes("^ff0000Red ring bringing up jealousy^000000")
          |> mes("^ff0000Red ring enchanted^000000")
          |> mes("^ff0000My sister envies^000000")
          |> next()
          |> mes("^ff0000Cold hand tightening my neck^000000")
          |> mes("^ff0000Cold eyes tightening my heart^000000")
          |> mes("^ff0000Cold marsh swallowing my body^000000")
          |> mes("^ff0000Red ring taken away^000000")
          |> mes("^ff0000Red ring enchanted^000000")
          |> emotion(:huk)

        ctx =
          ctx
          |> emotion(:think, playerattached(ctx))
          |> next()
          |> mes("[Ryubaba]")
          |> mes("S, stop! You'd better stop!?")
          |> next()

        ctx =
          ctx
          |> mes(player_name(ctx))
          |> mes("Isn't this voice Mashenka's!? What did you do to her!?")
          |> next()
          |> mes("[Ryubaba]")
          |> mes(
            "... I hated her. My father... father loved only her! He didn't talk to me, only to her!"
          )
          |> next()
          |> mes("[Ryubaba]")
          |> mes(
            "I asked her to show me the ring. But, she wouldn't let me see it. She always got on my nerves! Stupid girl!"
          )
          |> next()

        ctx =
          ctx
          |> mes(player_name(ctx))
          |> mes("She was your sister! How can you speak like that!?")
          |> mes("Your father needs to know about all of this!")
          |> next()
          |> mes("[Ryubaba]")
          |> mes("No!!!")
          |> mes("Give me that flute!")
          |> next()

        ctx =
          ctx
          |> mes(player_name(ctx))
          |> mes("No! Your father has to know!")
          |> next()
          |> mes("[Ryubaba]")
          |> mes("Please, I am begging you... Don't tell my father...")
          |> emotion(:cry)
          |> next()
          |> mes("- Suddenly, she sheds -")
          |> mes("- tears and kneels down -")
          |> next()
          |> mes("[Ryubaba]")
          |> mes(
            "I have been always worried that someone would find out... He has been feeling bad ever since what happened. How much worse would he feel if he knew the truth...?"
          )
          |> next()
          |> mes("[Ryubaba]")
          |> mes(
            "Could you please ignore this? Give me that flute... Ah... The red ring? How about exchanging it for the ring? Don't you need this?"
          )
          |> next()

        ctx =
          ctx
          |> mes(player_name(ctx))
          |> mes("But...")
          |> next()
          |> mes("[Ryubaba]")
          |> mes(
            "Oh, please.. This is not only for my sake, but also for my old father.... please I beg you."
          )
          |> next()

        {ctx, choice} =
          ctx
          |> mes(player_name(ctx))
          |> mes("...Mmmm, what should I do...")
          |> next()
          |> select(["Exchange", "Not exchange"])

        if choice == 1 do
          ctx =
            ctx
            |> mes(player_name(ctx))
            |> mes("...Mmmm, what should I do...")
            |> mes("Ok, I will do it.")
            |> next()

          ctx =
            ctx
            |> mes("[Ryubaba]")
            |> mes("Are you sure!? Thank you!")
            |> next()
            |> mes("[Ryubaba]")
            |> mes("I have to repent for my sins and atone for them for the rest of my life.")
            |> delitem(7883, 1)
            |> give_item(7877, 1)
            |> set_char_var(:rhea_rus_ring, 9)

          ctx |> reward_experience() |> close()
        else
          ctx =
            ctx
            |> mes(player_name(ctx))
            |> mes("...Mmmm, what should I do...")
            |> mes("No, I can't do it!")
            |> next()
            |> mes("[Ryubaba]")
            |> mes("What!!!")
            |> next()

          ctx
          |> mes(player_name(ctx))
          |> mes("I have to let your father know the truth! He has to know what you have done!")
          |> next()
          |> mes("[Ryubaba]")
          |> mes("W, wait!!!")
          |> set_char_var(:rhea_rus_ring, 8)
          |> close2()
          |> warp("moscovia", 203, 80)
        end
      else
        ctx =
          ctx
          |> mes(player_name(ctx))
          |> mes("...!? Where is the flute!?")

        ctx |> emotion(:huk, playerattached(ctx)) |> close()
      end
    end
  end

  defp ask_about_ring(ctx) do
    {ctx, _} =
      ctx
      |> mes("[Ryubaba]")
      |> mes("Huhu, have you ever met anyone as beautiful as I am?")
      |> next()
      |> select(["You are..."])

    {ctx, ring_name} =
      ctx
      |> mes(player_name(ctx))
      |> mes("...You are the most beautiful...")
      |> next()
      |> mes("[Ryubaba]")
      |> mes("Really? Everybody thinks so.")
      |> mes("Ah, I forgot asking you.")
      |> mes("Why are you here?")
      |> next()
      |> input(:string)

    ctx = ctx |> set_local(:"input$", ring_name) |> mes("[Ryubaba]")

    if get_local(ctx, :"input$", "") == "Red Ring" do
      ctx = ctx |> mes("A Red Ring?!") |> next()

      ctx
      |> ring_story()
      |> set_char_var(:rhea_rus_ring, 5)
      |> close()
    else
      ctx |> mes("Heh, what are you talking about? What is that?") |> close()
    end
  end

  defp offer_rose(ctx) do
    if count_item(ctx, 748) > 0 or count_item(ctx, 749) > 0 do
      ctx =
        ctx
        |> mes("[Ryubaba]")
        |> mes("What? Why are you here? You get of my...")
        |> next()
        |> mes("[Ryubaba]")
        |> mes("...Is that for me?")
        |> next()
        |> mes("[Ryubaba]")

      cond do
        Rathena.truthy?(count_item(ctx, 748)) ->
          ctx |> delitem(748, 1) |> forgive()

        Rathena.truthy?(count_item(ctx, 749)) ->
          ctx |> delitem(749, 1) |> forgive()

        true ->
          ctx
          |> mes("Well, I forgive.. eh?")
          |> next()
          |> mes("[Ryubaba]")
          |> mes("What? Are you trying to trick me!?")
          |> mes("I have never met a person ruder than you!")
          |> mes("I hate you! Get out of my face!")
          |> close2()
          |> warp("moscovia", 220, 210)
      end
    else
      dismiss_player(ctx)
    end
  end

  defp forgive(ctx) do
    ctx |> mes("Ok. Well, I forgive you.") |> set_char_var(:rhea_rus_ring, 4) |> close()
  end

  defp dismiss_player(ctx) do
    ctx
    |> mes("[Ryubaba]")
    |> mes("I have never met a person ruder than you!")
    |> mes("I hate you! Get out of my face!")
    |> close2()
    |> warp("moscovia", 220, 210)
  end

  defp first_meeting(ctx) do
    if getequipid(ctx, 2) != 2429 and getequipid(ctx, 2) != 2430 do
      ctx
      |> mes(player_name(ctx))
      |> mes("...Hmm, did I forget to wear something...?")
      |> close()
    else
      {ctx, answer} =
        ctx
        |> mes("[Ryubaba]")
        |> mes("Ah, how beautiful I am.")
        |> next()
        |> mes("[Ryubaba]")
        |> mes(
          "Mmm, you must be an adventurer? What would you say? Have you seen somebody more beautiful than me? I doubt it. How can you find anyone more beautiful than me?"
        )
        |> next()
        |> select(["Are you crazy!", "Yes, you are right."])

      if answer == 1 do
        ctx =
          ctx
          |> mes(player_name(ctx))
          |> mes(
            "Are you crazy!? Don't you know how wide the world is and how many beautiful people there are? You're pretty full of it, country girl!"
          )
          |> next()

        ctx = mes(ctx, player_name(ctx))

        ctx =
          if sex(ctx) == 0 do
            mes(
              ctx,
              "Besides, if there was a most beautiful girl in the world it would be me, me, me!"
            )
          else
            ctx
            |> mes("Have you seen dancers dancing? Have you seen beautiful and pure priests?!")
            |> mes("And nothing is like the kind Kafra Employees!!!")
          end

        ctx
        |> next()
        |> mes("[Ryubaba]")
        |> mes("What!? You bastard!!")
        |> mes("I hate you! Get out of my face!")
        |> set_char_var(:rhea_rus_ring, 2)
        |> close2()
        |> warp("moscovia", 220, 210)
      else
        ctx =
          ctx
          |> mes(player_name(ctx))
          |> mes("Yes, you are really beautiful.")

        ctx
        |> emotion(:smile, playerattached(ctx))
        |> next()
        |> mes("[Ryubaba]")
        |> mes(
          "Huhu, oh you jest. You know what you're talking about. Ah, this is a Choco drink that I have made. Give it a taste, isn't it good?"
        )
        |> set_char_var(:rhea_rus_ring, 4)
        |> give_item(573, 1)
        |> close()
      end
    end
  end

  defp player_name(ctx), do: Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]")
end
