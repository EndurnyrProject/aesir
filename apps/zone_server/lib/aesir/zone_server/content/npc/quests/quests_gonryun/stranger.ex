defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsGonryun.Stranger do
  @moduledoc """
  Zuo Hei directs the player to a blacksmith for the broken sword.

  ## Behavior

  - Asks the player to help another villager before sharing information.
  - Directs the player to Geffen after that task is complete.

  ## Credits

  - Original from rAthena, authors and Contributors
    - KarLaeda
    - L0ne_W0lf
    - Paradox924X

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "gonryun",
        x: 100,
        y: 241,
        dir: 0,
        sprite: 733,
        name: "Stranger",
        scope: :shared,
        unique_name: "Stranger#gnbs"
      }
    ]

  @impl true
  def on_talk(ctx) do
    sword = get_char_var(ctx, :b_sword, 0)

    cond do
      sword < 14 ->
        ctx
        |> mes("[Zuo Hei]")
        |> mes("Hmm...")
        |> mes("I'm pretty busy right now, come back later.")
        |> emotion(:think)
        |> close()

      sword == 14 ->
        ask_about_heirloom(ctx, get_char_var(ctx, :nakha, 0), 14)

      sword == 15 ->
        ctx
        |> mes("[Zuo Hei]")
        |> mes("Sorry, I'm busy right now.")
        |> mes("Why don't you come back later.")
        |> emotion(:think)
        |> close()

      sword == 16 ->
        ask_about_heirloom(ctx, get_char_var(ctx, :nakha, 0), 16)

      sword < 33 ->
        ctx
        |> mes("[Zuo Hei]")
        |> mes("Hey there...uhm..")
        |> mes("Didn't I tell you to go to ^FF0000Geffen^000000?")
        |> mes("You'll find a famous blacksmith")
        |> mes("that can repair the sword for you.")
        |> mes("That's all the information I can")
        |> mes("give you, really.")
        |> next()
        |> mes("[Zuo Hei]")
        |> mes("It's up to you to make good use of it.")
        |> close()

      true ->
        praise(ctx)
    end
  end

  defp ask_about_heirloom(ctx, 0, 14) do
    ctx
    |> mes("[Zuo Hei]")
    |> mes("Hmm...")
    |> mes("What is it?")
    |> mes("What do you want?")
    |> mes("I don't like to be bothered.")
    |> blacksmith_menu(:first)
  end

  defp ask_about_heirloom(ctx, status, 14) when status in [1, 2] do
    ctx
    |> mes("[Zuo Hei]")
    |> mes("Hmm...")
    |> mes("You're in the middle of helping")
    |> mes("someone now, I hear.")
    |> mes("Why don't you go and take care of them first.")
    |> mes("Once you start to help someone,")
    |> mes("you can't just quit halfway.")
    |> set_char_var(:b_sword, 16)
    |> close()
  end

  defp ask_about_heirloom(ctx, 3, 14) do
    ctx
    |> mes("[Zuo Hei]")
    |> mes("Hmm...")
    |> mes("What do you want??")
    |> blacksmith_menu(:completed)
  end

  defp ask_about_heirloom(ctx, 4, 14) do
    ctx
    |> mes("[Zuo Hei]")
    |> mes("Guess I was wasting my time.")
    |> mes("If you make a promise to someone,")
    |> mes("it's your responsibility to")
    |> mes("follow through with it to completion.")
    |> next()
    |> mes("[Zuo Hei]")
    |> mes("I don't like people who fail to")
    |> mes("keep the promises they make.")
    |> mes("You'll not get any information from me.")
    |> mes("Don't ever bother me again.")
    |> set_char_var(:b_sword, 15)
    |> close()
  end

  defp ask_about_heirloom(ctx, 0, 16) do
    ctx
    |> mes("[Zuo Hei]")
    |> mes("Hmm......")
    |> mes("You're not done with the")
    |> mes("requirement I've given you...")
    |> mes("I can't give you any information")
    |> mes("until you finish your job.")
    |> close()
  end

  defp ask_about_heirloom(ctx, status, 16) when status in [1, 2] do
    ctx
    |> mes("[Zuo Hei]")
    |> mes("Hmm....")
    |> mes("Once you start to help someone,")
    |> mes("you can't just quit halfway.")
    |> mes("Why don't you go and take care of them first.")
    |> close()
  end

  defp ask_about_heirloom(ctx, 3, 16) do
    ctx
    |> mes("[Zuo Hei]")
    |> mes("Hmm......")
    |> mes("What do you want?")
    |> blacksmith_menu(:returning)
  end

  defp ask_about_heirloom(ctx, 4, 16) do
    ctx
    |> mes("[Zuo Hei]")
    |> mes("Guess I was wasting my time.")
    |> mes("If you make a promise to")
    |> mes("someone, it's your")
    |> mes("responsibility to")
    |> mes("follow through with it to completion.")
    |> next()
    |> mes("[Zuo Hei]")
    |> mes("I don't like people who fail")
    |> mes("to keep their promises.")
    |> mes("You'll not get any information from me. Don't ever bother me again.")
    |> set_char_var(:b_sword, 15)
    |> close()
  end

  defp ask_about_heirloom(ctx, _, _), do: praise(ctx)

  defp blacksmith_menu(ctx, stage) do
    {ctx, choice} =
      ctx |> next() |> select(["Ask about the blacksmith.", "Why are you being so mean?"])

    if choice == 1 do
      ask_about_sword(ctx, stage)
    else
      ctx
      |> mes("[Zuo Hei]")
      |> mes("Grr...")
      |> mes("Why should you care about the")
      |> mes("someone else's personality?")
      |> mes("That's none of your business.")
      |> mes("Take a look in the mirror first")
      |> mes("before you say things like that.")
      |> emotion(:anger)
      |> close()
    end
  end

  defp ask_about_sword(ctx, stage) do
    ctx = mes(ctx, "[Zuo Hei]")

    {ctx, options} =
      case stage do
        :first ->
          {ctx
           |> mes("Ahh..")
           |> mes("So you're the one who found")
           |> mes("the sword, eh?")
           |> mes("Did you also get asked to repair it?"), ["Exactly.", "No..I'm just..."]}

        :completed ->
          {ctx
           |> mes("Ahh...")
           |> mes("So you are the one who found")
           |> mes("the sword, eh? I assume you were also asked to repair it..."),
           ["Exactly.", "No...I'm just..."]}

        :returning ->
          {ctx
           |> mes("Ahh...")
           |> mes("So you are the one who found")
           |> mes("the sword eh?")
           |> mes("Did you also get asked to repair it?"), ["Exactly.", "No, i'm just..."]}
      end

    {ctx, choice} = ctx |> next() |> select(options)

    cond do
      choice == 1 and stage == :first ->
        ctx
        |> mes("[Zuo Hei]")
        |> mes("Hmm...")
        |> mes("If you want some information from")
        |> mes("me, come back after helping the")
        |> mes("person in the village who's in")
        |> mes("trouble right now.")
        |> next()
        |> mes("[Zuo Hei]")
        |> mes("It's another heirloom")
        |> mes("problem, but I want to")
        |> mes("see for myself that")
        |> mes("you're really interested")
        |> mes("in helping others.")
        |> set_char_var(:b_sword, 16)
        |> close()

      choice == 1 ->
        ctx
        |> mes("[Zuo Hei]")
        |> mes("Hmm...")
        |> mes("Since it's been shattered,")
        |> mes("you'll need a very skilled smith.")
        |> mes("Go to ^FF0000Geffen^000000, you'll find someone")
        |> mes("who can help you.")
        |> set_char_var(:b_sword, 17)
        |> close()

      stage == :returning ->
        ctx
        |> mes("[Zuo Hei]")
        |> mes("Oh, I suppose not.")
        |> mes("Why are you asking me, then?")
        |> mes("Don't bother me anymore.")
        |> mes("I've got a bunch of things to do.")
        |> close()

      true ->
        ctx
        |> mes("[Zuo Hei]")
        |> mes("Hmm, I didn't think so...")
        |> mes("Now, don't bother me anymore.")
        |> mes("I've got a bunch of things to do.")
        |> close()
    end
  end

  defp praise(ctx) do
    ctx
    |> mes("[Zuo Hei]")
    |> mes("Hmm...")
    |> mes("Helping people in trouble is")
    |> mes("such a nice thing to do.")
    |> mes("You are doing the right thing.")
    |> close()
  end
end
