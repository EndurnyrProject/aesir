defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Jesqurienne do
  @moduledoc """
  Challenges the player to a quiz and awards a fragment of the Sobbing Starlight.

  ## Behavior

  - Introduces the quiz, reacts to its result, and directs the winner to Dearles.

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
        map: "geffen_in",
        x: 59,
        y: 74,
        dir: 4,
        sprite: 803,
        name: "Jesqurienne",
        scope: :shared,
        unique_name: "Jesqurienne#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnOmg", ctx) do
    ev_onomg(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnHo", ctx) do
    ev_onho(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Jesqurienne]")

    case get_char_var(ctx, :sign_q, 0) do
      stage when stage < 20 ->
        ctx |> mes("Bartender~?") |> mes("Give me another drink.") |> close()

      20 ->
        ctx |> mes("Bartender~?") |> mes("Give me another drink.") |> introduction()

      stage when stage in [21, 22] ->
        awaiting_quiz(ctx)

      23 ->
        quiz_loss(ctx)

      24 ->
        quiz_win(ctx)

      25 ->
        seek_dearles(ctx)

      _ ->
        dizzy(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp introduction(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Jesqurienne]")
      |> mes("Ahhhhhh~")
      |> mes("Hm? Why hello there,")

    ctx =
      if sex(ctx) == 1 do
        mes(ctx, "you fine speciman of a man~")
      else
        mes(ctx, "you precious, adorable girl~")
      end

    {ctx, recognition} =
      ctx
      |> mes("I'm Jesqurienne. You've heard")
      |> mes("of me, haven't you? Aren't you surprised to see me?")
      |> next()
      |> select(["I've never heard of you.", "Oh gosh, it's Jesqurienne!"])

    case recognition do
      1 -> ask_recognition(ctx)
      2 -> ctx |> boast() |> challenge()
      _ -> ctx
    end
  end

  defp ask_recognition(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Jesqurienne]")
      |> emotion(:sweat)
      |> mes("Ho ho ho~!")
      |> mes("Surely you")
      |> mes("must be joking~")
      |> next()
      |> select(["You got me, you got me.", "Nope. Doesn't ring a bell."])

    case answer do
      1 -> ctx |> emotion(:hng) |> boast() |> challenge()
      2 -> ctx |> insult() |> challenge()
      _ -> ctx
    end
  end

  defp boast(ctx) do
    ctx
    |> mes("[Jesqurienne]")
    |> mes("Ohohohohoho~!")
    |> mes("I knew it! I knew it!")
    |> mes("Then again, there's little")
    |> mes("that a famous genius like")
    |> mes("myself does ^333333not^000000 know!")
    |> next()
    |> mes("[Jesqurienne]")
    |> mes("Gah--!")
    |> mes("My glass is")
    |> mes("already empty?")
    |> mes("Bartender, another")
    |> mes("drink please~")
    |> next()
  end

  defp insult(ctx) do
    ctx
    |> emotion(:think)
    |> mes("[Jesqurienne]")
    |> mes("...")
    |> mes("......")
    |> mes("Now I understand.")
    |> mes("You've been living")
    |> mes("under a rock for all")
    |> mes("this time, haven't you?")
    |> next()
    |> mes("[Jesqurienne]")
    |> mes("But I guess someone")
    |> mes("as simple minded as you")
    |> mes("wouldn't recognize a famous,")
    |> mes("brilliant genius once you")
    |> mes("saw her, wouldn't you?")
    |> next()
  end

  defp challenge(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Jesqurienne]")
      |> mes("Anyway, I'm so proud")
      |> mes("of my supreme intelligence!")
      |> mes("I may be somewhat obsessive")
      |> mes("about studying, but that's just another reason to admire me~")
      |> next()
      |> mes("[Jesqurienne]")
      |> mes("The Wizard and Sage")
      |> mes("exams? No problem~")
      |> mes("Even the Alchemist test")
      |> mes("was fairly simple. So far")
      |> mes("I haven't met anyone")
      |> mes("smarter than me~")
      |> next()
      |> select(["^333333Stuck-up chick.^000000", "Take it easy on the drinks..."])

    case choice do
      1 -> begin_quiz(ctx)
      2 -> drinking(ctx)
      _ -> ctx
    end
  end

  defp begin_quiz(ctx) do
    ctx =
      ctx
      |> emotion(:fret)
      |> mes("[Jesqurienne]")
      |> mes("What...?")
      |> mes("What did you say?")
      |> mes("No one has ever")
      |> mes("said anything like")
      |> mes("that to me before!")
      |> mes("H-how dare you...")
      |> next()
      |> emotion(:anger)
      |> mes("[Jesqurienne]")
      |> mes("Prove that you can")
      |> mes("hold a candle to my")
      |> mes("superior intellect and")
      |> mes("I'll be willing to accept")
      |> mes("your little insult! It's time")
      |> mes("for a Quiz Challenge!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Quiz... Challenge?")
      |> mes("Like a trivia game?")
      |> mes("But who's going to")
      |> mes("ask us the questions?")
      |> next()
      |> donpcevent("Aaron#sign::onSmile")
      |> emotion(:surprise)

    ctx
    |> emotion(:surprise, playerattached(ctx))
    |> mes("[Aaron]")
    |> mes("Did someone say")
    |> mes("''Quiz Challenge?''")
    |> mes("I believe I can be")
    |> mes("of assistance.")
    |> next()
    |> set_char_var(:sign_q, 21)
    |> emotion(:kik)
    |> mes("[Jesqurienne]")
    |> mes("Professor Aaron?")
    |> mes("Ho ho~ If he's asking")
    |> mes("the questions, it looks")
    |> mes("like your chances of")
    |> mes("beating me are zero!")
    |> close()
  end

  defp drinking(ctx) do
    ctx
    |> mes("[Jesqurienne]")
    |> mes("Ho ho ho~")
    |> mes("Plenty of people have")
    |> mes("told me not to drink so")
    |> mes("much. But once I start")
    |> mes("I can't stop. I love to")
    |> mes("drink that much!")
    |> next()
    |> mes("[Jesqurienne]")
    |> mes("And...")
    |> mes("Sometimes I'd rather")
    |> mes("look at the world through")
    |> mes("these hazy eyes. See things")
    |> mes("the way I want to see them...")
    |> close()
  end

  defp awaiting_quiz(ctx) do
    ctx
    |> mes("It amuses me that")
    |> mes("you think that you'd")
    |> mes("stand a chance against")
    |> mes("me in a Quiz Challenge.")
    |> mes("Ho ho ho ho ho~!")
    |> next()
    |> mes("[Jesqurienne]")
    |> mes("Professor Aaron")
    |> mes("is waiting for you")
    |> mes("to ask him to begin.")
    |> mes("And I'm waiting for the")
    |> mes("moment when you realize")
    |> mes("you have no hope of winning!")
    |> close()
  end

  defp quiz_loss(ctx) do
    {ctx, choice} =
      ctx
      |> mes("Bwahahahaha!")
      |> mes("You should have known")
      |> mes("from the beginning that you")
      |> mes("never had a chance! Of course,")
      |> mes("I did, but you know, I guess you had to learn for yourself.")
      |> next()
      |> emotion(:fret)
      |> mes("[Jesqurienne]")
      |> mes(
        "I'd insult you if it weren't for the fact that you embarassed yourself enough during the Quiz Challenge. As a matter of fact, I'll even forgive you for wounding my pride earlier."
      )
      |> next()
      |> emotion(:kik)
      |> mes("[Jesqurienne]")
      |> mes("Can you believe it?")
      |> mes("Even drunk I can beat")
      |> mes("you in a test of intelligence!")
      |> mes("Bwahaha! I can't believe how")
      |> mes("simple minded you are...!")
      |> next()
      |> select(["I can't let you win!", "Darn it..."])

    case choice do
      1 ->
        ctx
        |> set_char_var(:sign_q, 22)
        |> mes("[Jesqurienne]")
        |> mes("You're a slow learner,")
        |> mes("aren't you? Well, I welcome")
        |> mes("your ''challenge'' anytime!")
        |> mes("Bwah hah hah hah hah~!")
        |> close()

      2 ->
        ctx
        |> mes("[Jesqurienne]")
        |> mes("Just now you realize")
        |> mes("how pitiful your intellect")
        |> mes("is compared to mine? Ho ho ho!")
        |> mes("There's hope for every fool!")
        |> close()

      _ ->
        ctx
    end
  end

  defp quiz_win(ctx) do
    {ctx, name} =
      ctx
      |> mes("What...?")
      |> mes("I... I...")
      |> mes("I don't b-believe it.")
      |> next()
      |> mes("[Jesqurienne]")
      |> mes("I lost...")
      |> mes("M-maybe you were right.")
      |> mes("I am arrogant after all...")
      |> mes("I should stop drinking so")
      |> mes("much. Travel around and")
      |> mes("broaden my knowledge...")
      |> next()
      |> mes("[Jesqurienne]")
      |> mes("You're the only")
      |> mes("one who has been")
      |> mes("able to beat me in")
      |> mes("a battle of minds.")
      |> mes("W-who are you...?")
      |> next()
      |> input(:string)

    ctx = ctx |> set_local(:"input$", name) |> mes("[Jesqurienne]")

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("", get_local(ctx, :"input$", "")), "..."))
      |> mes("I will remember that.")
      |> next()
      |> mes("[Jesqurienne]")
      |> set_char_var(:sign_q, 25)
      |> give_item(7177, 1)
      |> mes("Here...")
      |> mes("My old friend, Metz, told")
      |> mes("me to give this to someone")
      |> mes("who is worthy. I was going")
      |> mes("to keep it, but I suppose")
      |> mes("you're its true owner...")
      |> next()
      |> mes("[Jesqurienne]")
      |> mes(
        "If you want to know more about the Sobbing Starlight, find a man named ^3131CEDearles^000000. It may be hard to find him since he wanders from place to place, but it might help to know that he loves gambling..."
      )
      |> next()
      |> mes("[Jesqurienne]")
      |> mes("Good luck finding")
      |> mes("Dearles. I'm taking")
      |> mes("this loss pretty badly,")
      |> mes("so I think I'll stay here")
      |> mes("and have another drink.")

    ctx
    |> mes(Rathena.concat(Rathena.concat("Farewell, ", get_local(ctx, :"input$", "")), "."))
    |> close()
  end

  defp seek_dearles(ctx) do
    ctx
    |> mes("Ooooh...")
    |> mes("My head...")
    |> mes("Oh...! It's you...!")
    |> mes("So did you find Dearles?")
    |> next()
    |> mes("[Jesqurienne]")
    |> mes("Hmm...")
    |> mes("He's addicted to")
    |> mes("gambling, so maybe you")
    |> mes("can find him some place")
    |> mes("where you can do that...")
    |> close()
  end

  defp dizzy(ctx) do
    ctx
    |> mes("OoOooOhh~")
    |> mes("Sooooo dizzy.")
    |> mes("Maybe I drank")
    |> mes("too much again~")
    |> close()
  end

  def ev_onomg(ctx), do: emotion(ctx, :huk)
  def ev_onho(ctx), do: emotion(ctx, :delight)
end
