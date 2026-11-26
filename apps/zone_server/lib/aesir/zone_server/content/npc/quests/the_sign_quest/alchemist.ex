defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Alchemist do
  @moduledoc """
  Melkaba prepares Vigorgra for The Sign quest.

  ## Behavior

  - Discusses her research and prepares Vigorgra when the adventurer provides the ingredients and fee.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alde_alche",
        x: 169,
        y: 162,
        dir: 7,
        sprite: 749,
        name: "Alchemist",
        scope: :shared,
        unique_name: "Alchemist#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Melkaba]")
    stage = get_char_var(ctx, :sign_q, 0)

    cond do
      stage < 46 -> research_before_quest(ctx)
      stage == 46 -> request_vigorgra(ctx)
      stage == 47 -> prepare_vigorgra(ctx)
      stage in [97, 98] -> research_after_quest(ctx)
      true -> warn_about_vigorgra(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp research_before_quest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Most Alchemists seek out the")
      |> mes(
        "Stone of Sage, but in my opinion, their goals are too short sighted. There are more important studies"
      )
      |> mes("to be conducted in the name of science for the good of mankind...")
      |> next()
      |> select(["...", "So what are you studying?"])

    case choice do
      1 ->
        ctx
        |> mes("[Melkaba]")
        |> mes("In the end, the ")
        |> mes("Stone of Sage may")
        |> mes("just be a simple rumor.")
        |> mes("After all, thousands of")
        |> mes("Alchemists have already")
        |> mes("failed to create it.")
        |> close()

      2 ->
        ctx
        |> mes("[Melkaba]")
        |> mes("What am I studying?")
        |> mes("Well, my expertise is...")
        |> mes("Different. If you must")
        |> mes("know, it's a secret~")
        |> mes("If any man found out")
        |> mes("about my research...")
        |> close()

      _ ->
        ctx
    end
  end

  defp request_vigorgra(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Eh...?")
      |> mes("What do you need?")
      |> mes("If it's not important,")
      |> mes("please leave my")
      |> mes("laboratory!")
      |> next()
      |> select(["Vigorgra?", "Oh, I'm sorry."])

    case choice do
      1 ->
        {ctx, reason} =
          ctx
          |> mes("[Melkaba]")
          |> mes("What?! Who told you")
          |> mes("that I could make that?!")
          |> mes("Oh, no matter. I suppose")
          |> mes("you want me to get some")
          |> mes("ready for you. Now tell me...")
          |> mes("Why do you want it?")
          |> next()
          |> select(["No, I don't want it!", "I need Vigorgra for... a friend."])

        case reason do
          1 ->
            ctx
            |> mes("[Melkaba]")
            |> mes("You immature--!")
            |> mes("You come all this")
            |> mes("way to bother me?")
            |> mes("Don't bring your")
            |> mes("shame into my lab!")
            |> close()

          2 ->
            ctx
            |> mes("[Melkaba]")
            |> mes("Oh right.")
            |> mes("Your friend.")
            |> mes("I understand you.")
            |> mes("Crystal clear.")
            |> next()
            |> mes("[Melkaba]")
            |> mes("Well, since you know")
            |> mes("about my secret research,")
            |> mes("I'll do you a favor so long as")
            |> mes("you don't tell anyone else!")
            |> mes("Of course, I can't just give")
            |> mes("you Vigorgra for free...")
            |> next()
            |> mes("[Melkaba]")
            |> mes("Now, write this")
            |> mes("down. These are the")
            |> mes("ingredients I need to")
            |> mes("make a bottle of Vigorgra.")
            |> next()
            |> mes("[Melkaba]")
            |> mes("^ff00001 Ment")
            |> mes("20 Honey")
            |> mes("10 Royal Jelly")
            |> mes("30 Bear's Footskin")
            |> mes("1 Hinalle Leaflet")
            |> mes("1 Empty Bottle.^000000")
            |> next()
            |> mes("[Melkaba]")
            |> mes("Alright.")
            |> mes("Now go and")
            |> mes("bring all those")
            |> mes("items to me. I'll")
            |> mes("be seeing you later.")
            |> set_char_var(:sign_q, 47)
            |> close()

          _ ->
            ctx
        end

      2 ->
        ctx
        |> mes("[Melkaba]")
        |> mes("There's no need")
        |> mes("to apologize. But")
        |> mes("I'd appreciate it if")
        |> mes("you'd let me work")
        |> mes("in peace.")
        |> close()

      _ ->
        ctx
    end
  end

  defp prepare_vigorgra(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Hmmm...")
      |> mes("So did you")
      |> mes("bring everything")
      |> mes("you need for the")
      |> mes("Vigorgra...?")
      |> next()
      |> select(["Not yet...", "Yes."])

    case choice do
      1 ->
        ctx
        |> mes("[Melkaba]")
        |> mes("Well, let me")
        |> mes("remind you of")
        |> mes("what you need to")
        |> mes("bring to me in case")
        |> mes("you forgot already...")
        |> next()
        |> mes("[Melkaba]")
        |> mes("^ff00001 Ment")
        |> mes("20 Honey")
        |> mes("10 Royal Jelly")
        |> mes("30 Bear's Footskin")
        |> mes("1 Hinalle Leaflet")
        |> mes("1 Empty Bottle.^000000")
        |> next()
        |> mes("[Melkaba]")
        |> mes("Take your time...")
        |> mes("In the end, you're")
        |> mes("the one who's got")
        |> mes("the need for it, anyway.")
        |> close()

      2 ->
        ctx =
          ctx
          |> mes("[Melkaba]")
          |> mes("Great...!")
          |> mes("Now let me check")
          |> mes("to see if you have")
          |> mes("everything ready...")
          |> next()
          |> mes("[Melkaba]")

        if count_item(ctx, 526) < 10 or count_item(ctx, 518) < 20 or count_item(ctx, 948) < 30 or
             count_item(ctx, 520) < 1 or count_item(ctx, 708) < 1 or count_item(ctx, 713) < 1 do
          ctx
          |> mes("Hmm, you're still")
          |> mes("missing some of the")
          |> mes("ingredients. Now, listen")
          |> mes("carefully. I need you to get...")
          |> next()
          |> mes("[Melkaba]")
          |> mes("^ff00001 Ment")
          |> mes("20 Honey")
          |> mes("10 Royal Jelly")
          |> mes("30 Bear's Footskin")
          |> mes("1 Hinalle Leaflet")
          |> mes("1 Empty Bottle.^000000")
          |> close()
        else
          ctx =
            ctx
            |> mes("Good work.")
            |> mes("Everything's here.")
            |> mes("Alright, just this once")
            |> mes("I'll make you a bottle")
            |> mes("of Vigorgra.")
            |> next()
            |> mes("[Melkaba]")
            |> mes("If you ask me again,")
            |> mes("I won't speak to you!")
            |> mes("And I'll need to charge")
            |> mes("you 10,000 zeny.")
            |> next()
            |> mes("[Melkaba]")

          if zeny(ctx) < 10000 do
            ctx
            |> mes("Huh...")
            |> mes("It doesn't look like")
            |> mes("you have enough zeny")
            |> mes("right now. No matter,")
            |> mes("I can wait until you")
            |> mes("bring it all to me.")
          else
            ctx =
              ctx
              |> mes("Alright, I'll be")
              |> mes("taking my fee from")
              |> mes("you now. It's not that")
              |> mes("expensive when you")
              |> mes("consider Vigorgra's")
              |> mes("numerous benefits.")
              |> next()
              |> mes("^3355FFMelkaba placed")
              |> mes("all the ingredients")
              |> mes("into a test tube and")
              |> mes("began processing it")
              |> mes("through some strange")
              |> mes("electronic equipment.^000000")
              |> next()
              |> mes("...")
              |> mes("......")
              |> next()
              |> mes("...")
              |> mes("......")
              |> mes(".........")
              |> next()
              |> mes("[Melkaba]")

            if Enum.random(1..100) < 98 do
              ctx
              |> specialeffect(:pharmacy_ok)
              |> mes("Ah! Success!")
              |> mes("A lifetime's supply")
              |> mes("of Vigorgra! I know it's")
              |> mes("just one bottle, but this")
              |> mes("stuff is extremely potent!")
              |> next()
              |> pay_zeny(10000)
              |> delitem(526, 10)
              |> delitem(518, 20)
              |> delitem(948, 30)
              |> delitem(520, 1)
              |> delitem(708, 1)
              |> delitem(713, 1)
              |> set_char_var(:sign_q, 48)
              |> give_item(7044, 1)
              |> mes("[Melkaba]")
              |> mes("Um, just remember")
              |> mes("not to take too much")
              |> mes("at one time. Can't have")
              |> mes("you getting crazy high")
              |> mes("blood pressure~")
              |> close()
            else
              ctx
              |> specialeffect(:pharmacy_fail)
              |> delitem(526, 10)
              |> delitem(518, 20)
              |> delitem(948, 30)
              |> delitem(520, 1)
              |> delitem(708, 1)
              |> delitem(713, 1)
              |> mes("It failed?!")
              |> mes("Of course, the mixture")
              |> mes("was too vigorous, even")
              |> mes("for the machinery! I'm sorry,")
              |> mes("but would you bring the things")
              |> mes("we need to make Vigorgra again?")
              |> close()
            end
          end
        end

      _ ->
        ctx
    end
  end

  defp research_after_quest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Most Alchemists seek out the")
      |> mes(
        "Stone of Sage, but in my opinion, their goals are too short sighted. There are more important studies"
      )
      |> mes("to be conducted in the name of science for the good of mankind...")
      |> next()
      |> select(["...", "So what are you studying?"])

    case choice do
      1 ->
        ctx
        |> mes("[Melkaba]")
        |> mes("In the end, the")
        |> mes("Stone of Sage may")
        |> mes("just be a simple rumor.")
        |> mes("After all, thousands of")
        |> mes("Alchemists have already")
        |> mes("failed to create it.")
        |> close()

      2 ->
        ctx
        |> mes("[Melkaba]")
        |> mes("What am I studying?")
        |> mes("Well, my expertise is...")
        |> mes("Different. If you must")
        |> mes("know, it's a secret~")
        |> mes("If any man found out")
        |> mes("about my research...")
        |> close()

      _ ->
        ctx
    end
  end

  defp warn_about_vigorgra(ctx) do
    ctx
    |> mes("Vigorgra is")
    |> mes("a miracle of")
    |> mes("modern science,")
    |> mes("but it can do more")
    |> mes("harm than good if")
    |> mes("you're not careful!")
    |> close()
  end
end
