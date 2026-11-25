defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.VassiliGrandpapa do
  @moduledoc """
  Vassili Grandpapa helps the player uncover the fate of his daughter and the Red Ring.

  ## Behavior

  - Discusses his family and the ring as the quest progresses.
  - Exchanges Mashenka's flute for the ring and awards experience or an item.

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
        x: 206,
        y: 81,
        dir: 0,
        sprite: 712,
        name: "Vassili Grandpapa",
        scope: :shared,
        unique_name: "Vassili Grandpapa#rus07"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      max_weight(ctx) - weight(ctx) < 3500 -> overloaded(ctx)
      get_char_var(ctx, :rhea_rus_main, 0) < 8 -> greeting(ctx)
      get_char_var(ctx, :rhea_rus_main, 0) == 8 -> ring_quest(ctx)
      true -> farewell(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp overloaded(ctx) do
    ctx
    |> mes("[Vassili Grandpapa]")
    |> mes("Why are you carring that much?")
    |> mes("Are you training for something?")
    |> close()
  end

  defp greeting(ctx) do
    ctx
    |> mes("[Vassili Grandpapa]")
    |> mes("Hmm, are you an adventurer? So, how do you like it here?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("It's not too bad.")
    |> mes("The weather here is great!")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "Even though it is fine now in Moscovia, it is not such a great place during the harsh winter season."
    )
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("Eeee, I don't want to experience that coldness any more.")
    |> close()
  end

  defp ring_quest(ctx) do
    ring = get_char_var(ctx, :rhea_rus_ring, 0)

    cond do
      ring == 0 and not wearing_shoes?(ctx) -> missing_shoes(ctx)
      ring == 0 -> ask_about_ring(ctx)
      ring < 8 -> remember_daughter(ctx)
      ring == 8 and not wearing_shoes?(ctx) -> missing_shoes(ctx)
      ring == 8 -> play_flute(ctx)
      ring == 9 -> mourn_daughter(ctx)
      true -> farewell(ctx)
    end
  end

  defp wearing_shoes?(ctx), do: getequipid(ctx, 2) in [2429, 2430]

  defp missing_shoes(ctx) do
    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...Hmm, did I forget to wear something...?")
    |> close()
  end

  defp ask_about_ring(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Vassili Grandpapa]")
      |> mes("Hmm, are you an adventurer? So, how do you like it here?")
      |> next()
      |> select(["It's so-so", "I have something to ask..."])

    case choice do
      1 ->
        ctx
        |> mes("[Vassili Grandpapa]")
        |> mes(
          "Hmm, you have traveled so much. I guess if you're tired from your trip then it's only natural, huhu."
        )
        |> close()

      2 ->
        inquire(ctx)

      _ ->
        ctx
    end
  end

  defp inquire(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Vassili Grandpapa]")
      |> mes("Eh? What do you want to ask me about?")
      |> next()
      |> input(:string)

    ctx = set_local(ctx, :"input$", answer)

    if get_local(ctx, :"input$", "") == "Red Ring" do
      tell_story(ctx)
    else
      ctx
      |> mes("[Vassili Grandpapa]")
      |> mes("Mmm, what? I don't understand you.")
      |> close()
    end
  end

  defp tell_story(ctx) do
    ctx
    |> mes("[Vassili Grandpapa]")
    |> mes("Red Ring?! Why are you looking for that?")
    |> next()
    |> mes("- You tell him about the -")
    |> mes("- Gray Wolf and Maria -")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("Huuuh, I see.")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("What should I do?")
    |> mes("I want to help but I can't.")
    |> mes("I gave it to my youngest")
    |> mes("daughter, Mashenka,")
    |> mes("as a present. But... she...")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Are you ok?")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("It's just that Mashenka...")
    |> mes("..........")
    |> mes("....she died...")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "She was really pretty and smart. My first daughter, Ryubaba, is also pretty and smart but her temper is..."
    )
    |> mes("hotter than Ifrit's flames!")
    |> mes("Do you know what I mean?")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "Anyway, Mashenka was such a kind and tender daughter. On cold winter nights, when I came back home late, she would wait for me with a hot bowl of my favorite stew."
    )
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "How couldn't I be touched by such kindness? So, I gave the Red Ring to her as a gift."
    )
    |> mes("I can still remember how happy she was when I gave it to her.")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "She disappeared soon... after Now all I have is Ryubaba. She is also pretty and smart but nothing can relieve the sadnesss in my heart from losing Mashenka..."
    )
    |> set_char_var(:rhea_rus_ring, 1)
    |> close()
  end

  defp remember_daughter(ctx) do
    ctx
    |> mes("[Vassili Grandpapa]")
    |> mes("I can still remember how happy she was when I gave it to her.")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "She disappeared soon... after Now all I have is Ryubaba. She is also pretty and smart but nothing can relieve the sadnesss in my heart from losing Mashenka..."
    )
    |> close()
  end

  defp play_flute(ctx) do
    ctx =
      ctx
      |> mes("[Vassili Grandpapa]")
      |> mes("Ehh? you are the adventurer that I met before. Something to tell me?")
      |> next()
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("...Listen to... this.")
      |> next()

    if Rathena.truthy?(count_item(ctx, 7883)) do
      reveal_truth(ctx)
    else
      missing_flute(ctx)
    end
  end

  defp reveal_truth(ctx) do
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
    |> emotion(:think, playerattached(ctx))
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("...W, what is this? Ehh??")
    |> mes("My daughter, Mashenka, was.. by Ryubaba...!?")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("No... this isn't true?")
    |> mes("Don't try to trick me... Why are you telling... That flute is... Mashenka...")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Isn't this.. isn't this Mashenka's voice?")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("Don't tell me those lies about..!! My daughters... That...")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(".............................")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(".............................")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(".............................")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(".............................")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(".............................")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(".............................")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(".............................")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("...Uh... I'm so sorry...")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("... Can you please... play the flute again?")
    |> next()
    |> mes("- You play the flute -")
    |> mes("- with Mashenka's voice -")
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
    |> emotion(:think)
    |> emotion(:think, playerattached(ctx))
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("It is.. It is true...")
    |> mes(
      "When I saw this ring in Ryubaba's room, I never thought that. But, it has to be true..."
    )
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("Damn this cursed ring!!! Why did my daughters have this tragedy....? ~Sob!")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("......................")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "........i'm sorry. ...I know that this wasn't easy for you to tell me. Thank you for the truth."
    )
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes("You said you needed this ring, right? Take it...")
    |> mes("It has brought me nothing but grief.")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "...It is my fault that this tragedy between my daughters happened. I will spend the rest of my life trying to make up for it..."
    )
    |> delitem(7883, 1)
    |> give_item(7877, 1)
    |> set_char_var(:rhea_rus_ring, 10)
    |> reward()
    |> close()
  end

  defp reward(ctx) do
    level = base_level(ctx)

    if Rathena.truthy?(checkre(ctx, 3)) do
      experience =
        cond do
          level < 56 -> 470
          level < 61 -> 615
          level < 66 -> 750
          level < 71 -> 1000
          level < 76 -> 1500
          level < 81 -> 2000
          level < 86 -> 4500
          level < 91 -> 8500
          true -> 30000
        end

      ctx = if level >= 275, do: give_item(ctx, 607, 1), else: ctx
      getexp(ctx, experience, 0)
    else
      experience =
        cond do
          level < 56 -> 4700
          level < 61 -> 6150
          level < 66 -> 10605
          level < 71 -> 16223
          level < 76 -> 41227
          level < 81 -> 69073
          level < 86 -> 85102
          level < 91 -> 104_615
          level < 99 -> 222_035
          true -> nil
        end

      if experience, do: getexp(ctx, experience, 0), else: give_item(ctx, 607, 1)
    end
  end

  defp missing_flute(ctx) do
    ctx
    |> mes("[Vassili Grandpapa]")
    |> mes("...............................")
    |> mes("...............................")
    |> mes("...What did you say?")
    |> next()
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("Ehh?! This is weird. Where is the flute?!")
    |> emotion(:huk, playerattached(ctx))
    |> close()
  end

  defp mourn_daughter(ctx) do
    ctx
    |> mes("[Vassili Grandpapa]")
    |> mes("You may think it is foolish but I cannot relieve the sadness of my lost daughter.")
    |> next()
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "It is parents that wander around the entrance of the village to wait for their children..."
    )
    |> close()
  end

  defp farewell(ctx) do
    ctx
    |> mes("[Vassili Grandpapa]")
    |> mes(
      "..It is my fault that this tragedy between my daughters happened. I will spend the rest of my life trying to make up for it..."
    )
    |> close()
  end
end
