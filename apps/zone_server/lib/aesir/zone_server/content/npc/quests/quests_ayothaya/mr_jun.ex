defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAyothaya.MrJun do
  @moduledoc """
  A lemon grower challenges visitors to rock-paper-scissors during the Tom Yum Goong quest.

  ## Behavior

  - Refuses interaction when the player is carrying too much weight.
  - At the lemon quest stage, offers ten lemons for winning his game.
  - After awarding the lemons, explains why he cannot give out more.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Fredzilla
    - MasterOfMuppets
    - Lupus
    - Silent
    - Evera
    - SinSloth
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "ayothaya",
        x: 121,
        y: 240,
        dir: 7,
        sprite: 842,
        name: "Mr. Jun",
        scope: :shared,
        unique_name: "Mr. Jun#ayo",
        trigger: {1, 1}
      }
    ]

  @knife 1201
  @lemon 568

  @impl true
  def on_event("OnTouch_", ctx) do
    cond do
      overweight?(ctx) -> overweight(ctx)
      get_char_var(ctx, :tomyumgoong, 0) == 4 -> offer_help(ctx)
      true -> greeting(ctx)
    end
  end

  @impl true
  def on_talk(ctx) do
    cond do
      overweight?(ctx) -> overweight(ctx)
      get_char_var(ctx, :tomyumgoong, 0) == 5 -> ask_for_more(ctx)
      true -> greeting(ctx)
    end
  end

  defp overweight?(ctx),
    do: max_weight(ctx) - weight(ctx) < 2000 or checkweight(ctx, [{@knife, 1}]) == 0

  defp overweight(ctx) do
    ctx
    |> mes("- Wait a minute! -")
    |> mes("- Currently you're carrying -")
    |> mes("- too many items with you. -")
    |> mes("- Please enlighten your weight -")
    |> mes("- and try again. -")
    |> close()
  end

  defp greeting(ctx), do: ctx |> mes("[Mr. Jun]") |> mes("...") |> close()

  defp ask_for_more(ctx) do
    {ctx, choice} =
      ctx
      |> emotion(:sweat)
      |> mes("[Mr. Jun]")
      |> mes("Umm...?")
      |> mes("You don't need")
      |> mes("more Lemons")
      |> mes("again, do you?")
      |> next()
      |> select(["No.", "Give me Lemons, old man!", "Can I have some more Lemons, please?"])

    case choice do
      1 ->
        ctx
        |> emotion(:delight)
        |> mes("[Mr. Jun]")
        |> mes("Then why don't you taste")
        |> mes("the Lemons I gave you last time? They're really sour, but also very delicious!")
        |> close()

      2 ->
        ctx
        |> emotion(:fret)
        |> mes("[Mr. Jun]")
        |> mes("What...!?")
        |> mes("What's wrong with you, kid?")
        |> mes("What have you done with the")
        |> mes("Lemons I gave you last time?")
        |> close()

      3 ->
        ctx
        |> mes("[Mr. Jun]")
        |> mes("Oh, I am sorry....recently my lemon storage")
        |> mes("was attacked by ^3131FF'Leaf Cats'^000000 that are roaming around the Shrine.")
        |> next()
        |> mes("[Mr. Jun]")
        |> mes("I wish that I could help you,")
        |> mes("but I don't even have enough lemons for my business.")
        |> mes("If you need lemons, why don't you go hunt them?")
        |> close()

      _ ->
        ctx
    end
  end

  defp offer_help(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mr. Jun]")
      |> mes("Hello, there?")
      |> mes("Did you need")
      |> mes("some help...?")
      |> emotion(:scratch)
      |> next()
      |> select(["I need some Lemons.", "No, thanks."])

    if choice == 1 do
      request_lemons(ctx)
    else
      ctx
      |> mes("[Mr. Jun]")
      |> mes("Feel free to")
      |> mes("ask me for help")
      |> mes("any time, okay?")
      |> close()
    end
  end

  defp request_lemons(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mr. Jun]")
      |> mes("Umm...")
      |> mes("Lemons?")
      |> mes("As you see, I have plenty")
      |> mes("of Lemons on my tree.")
      |> mes("Do you really need some?")
      |> next()
      |> select(["Yes, I will pay you.", "No, thanks."])

    if choice == 1 do
      offer_game(ctx)
    else
      ctx
      |> mes("[Mr. Jun]")
      |> mes("Hmm...")
      |> mes("Now what can")
      |> mes("I possibly do")
      |> mes("with all these")
      |> mes("Lemons?")
      |> close()
    end
  end

  defp offer_game(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Mr. Jun]")
      |> mes(
        "I started growing this Lemon tree as a hobby, but I didn't expect to have such a good harvest of sweet,"
      )
      |> mes("succulent Lemons.")
      |> next()
      |> mes("[Mr. Jun]")
      |> mes("Did you just say you were")
      |> mes("going to pay me for the Lemons?")
      |> mes("Oh, you've got me wrong. I don't intend to sell these.")
      |> next()
      |> mes("[Mr. Jun]")
      |> mes("But...")
      |> mes("I'm more than willing")
      |> mes("to share some of them with")
      |> mes("you, but only if you can...")
      |> next()
      |> mes("[Mr. Jun]")
      |> mes("Play a small game with me!")
      |> mes(
        "How about that? I've been so bored to death. Even an old man like me needs to enjoy himself!"
      )
      |> next()
      |> mes("[Mr. Jun]")
      |> mes("Hahahaha~!")
      |> mes("What do you say?")
      |> mes("Would you like to try?")
      |> next()
      |> select(["Sure, why not!", "No, thanks."])

    if choice == 1 do
      play_game(ctx)
    else
      ctx
      |> mes("[Mr. Jun]")
      |> mes("Afraid are we?")
      |> mes("There's no fooling you:")
      |> mes("I'm one of the best at games!")
      |> close()
    end
  end

  defp play_game(ctx) do
    ctx =
      ctx
      |> mes("[Mr. Jun]")
      |> mes("Good!")
      |> mes("The game I want us")
      |> mes("to play is an easy")
      |> mes("children's game.")
      |> next()
      |> mes("[Mr. Jun]")
      |> mes("^660000Rock,")
      |> mes("Paper, Scissors!^000000")
      |> mes("Perhaps you've heard")
      |> mes("of it in your land.")
      |> emotion(:scissor)
      |> next()
      |> mes("[Mr. Jun]")
      |> mes(
        "Nuh-uh, don't look at me like that. I'm an old man, and I want to play this game and re-live my youth"
      )
      |> mes("a little bit. You'll understand when you're my age.")
      |> next()
      |> mes("[Mr. Jun]")
      |> mes("Alright, if you win")
      |> mes("^3131FF3^000000 out of ^3131FF5^000000 matches,")
      |> mes("The Lemons are yours.")
      |> mes("Are you ready?")
      |> next()
      |> mes("[Mr. Jun]")
      |> mes("Okay...")
      |> mes("As you kids say,")
      |> mes("^990000Let's get eXtreme!^000000")
      |> next()
      |> set_temp_var(:user_score, 0)
      |> set_temp_var(:pc_score, 0)
      |> mes("[Mr. Jun]")
      |> mes("Rock!")
      |> mes("Paper!")
      |> mes("Scissors!")
      |> next()
      |> play_rounds()

    case ctx do
      {:complete, ctx} ->
        if get_temp_var(ctx, :user_score, 0) == 3, do: win(ctx), else: lose(ctx)

      {:cancelled, ctx} ->
        ctx
    end
  end

  defp win(ctx) do
    ctx
    |> emotion(:hng)
    |> mes("[Mr. Jun]")
    |> mes("You... won.")
    |> mes("I'm so exhausted.")
    |> mes("I guess I can't compete")
    |> mes("with you youngsters")
    |> mes("anymore. Ha ha ha!")
    |> next()
    |> mes("[Mr. Jun]")
    |> mes("As promised,")
    |> mes("I shall share some")
    |> mes("of my Lemons with you.")
    |> mes("Grab as many as you want!")
    |> mes("^3355FFYou have plucked")
    |> mes("10 Lemons from the tree.^000000")
    |> set_char_var(:tomyumgoong, 5)
    |> give_item(@lemon, 10)
    |> next()
    |> emotion(:think)
    |> mes("[Mr. Jun]")
    |> mes("Hmm...")
    |> mes(
      "Looks like you need a lot of them. Oh well, that's fine with me. I had a good time with you."
    )
    |> next()
    |> mes("[Mr. Jun]")
    |> mes("Don't forget this though:")
    |> mes(
      "Don't be selfish, and always share what you have with others. That's one of the most important values for human beings."
    )
    |> close()
  end

  defp lose(ctx) do
    ctx
    |> emotion(:scissor)
    |> mes("[Mr. Jun]")
    |> mes("Muhahahaha!")
    |> mes("Victory is mine!")
    |> mes("Looks like you won't be getting")
    |> mes("any Lemons for now! But feel free to challenge me anytime!")
    |> close()
  end

  defp play_rounds(ctx) do
    if get_temp_var(ctx, :pc_score, 0) == 5 or get_temp_var(ctx, :user_score, 0) == 3 do
      {:complete, ctx}
    else
      {ctx, choice} =
        ctx
        |> set_local(:jun_mark, Enum.random(1..3))
        |> select(["Scissors", "Rock", "Paper"])

      if choice in 1..3 do
        ctx |> round(choice, get_local(ctx, :jun_mark, 0)) |> play_rounds()
      else
        {:cancelled, ctx}
      end
    end
  end

  defp round(ctx, choice, mark) do
    opponent = Enum.at([:scissor, :rock, :wrap], mark - 1)
    player = Enum.at([:scissor, :rock, :wrap], choice - 1)
    ctx = emotion(ctx, opponent)
    ctx = emotion(ctx, player, playerattached(ctx))

    case {choice, mark} do
      {same, same} ->
        ctx
        |> mes("[Mr. Jun]")
        |> mes("Hmpf.")
        |> mes("It's a draw.")
        |> mes("One more time!")
        |> mes("Rock! Paper!")
        |> mes("Scissors!")
        |> next()

      {1, 2} ->
        score(ctx, [:pc_score], ["Yes...!", "Oh my God, yes!"])

      {1, 3} ->
        score(ctx, [:pc_score, :user_score], ["What...?", "I don't believe it!", "Bah.. !"])

      {2, 1} ->
        score(ctx, [:pc_score, :user_score], ["No...!", "Sacrilege!"])

      {2, 3} ->
        score(ctx, [:pc_score], ["Bwahahaha!", "You lose, kid!"])

      {3, 1} ->
        score(ctx, [:pc_score], ["Heh heh~", "Young fool!"])

      {3, 2} ->
        score(ctx, [:user_score, :pc_score], ["Noooo...!", "This cannot be!"])
    end
  end

  defp score(ctx, scores, lines) do
    ctx =
      Enum.reduce(scores, ctx, fn score, acc ->
        set_temp_var(acc, score, get_temp_var(acc, score, 0) + 1)
      end)

    ctx
    |> mes("[Mr. Jun]")
    |> then(fn ctx -> Enum.reduce(lines, ctx, &mes(&2, &1)) end)
    |> next()
  end
end
