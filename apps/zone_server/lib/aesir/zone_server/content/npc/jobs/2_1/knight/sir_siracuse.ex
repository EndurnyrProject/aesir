defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.SirSiracuse do
  @moduledoc """
  Knight who runs the second Knight job test, a quiz on Knight knowledge and honor.

  ## Behavior

  - Quizzes candidates who passed Sir Andrew's test with five questions on Knight
    weapons and skills, then three on a Knight's conduct.
  - Any wrong answer fails the test, which may be retaken.
  - Passing advances the quest to Sir Windsor's test.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_in",
        x: 71,
        y: 91,
        dir: 0,
        sprite: 65,
        name: "Sir Siracuse",
        scope: :shared,
        unique_name: "Sir Siracuse#knt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Sir Siracuse]")

    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:swordman) do
      greet_non_swordman(ctx)
    else
      talk_about_test(ctx, get_char_var(ctx, :KNIGHT_Q, 0))
    end
  end

  defp greet_non_swordman(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:knight) -> greet_knight(ctx)
      Rathena.job_id(base_class(ctx)) == Rathena.job_id(:novice) -> greet_novice(ctx)
      true -> ponder_offense_and_defense(ctx)
    end
  end

  defp greet_knight(ctx) do
    ctx
    |> mes("Hey there!")
    |> mes("How are you doing?")
    |> mes("The Chivalry's been")
    |> mes("doing pretty well.")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes("We've been")
    |> mes("testing new members,")
    |> mes("but not all of them")
    |> mes("show as much promise")
    |> mes("as you.")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes("I hope these new recruits all behave themselves, and don't")
    |> mes("bring shame to the Chivalry.")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes(
      "If you catch any of the new guys acting in a way unbecoming of a Knight, scold them for me please?"
    )
    |> close()
  end

  defp greet_novice(ctx) do
    ctx
    |> mes("Oh?")
    |> mes("What is a Novice")
    |> mes("doing here?")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes(
      "Are you interested in becoming a Knight? You just can't change into a Knight from a Novice, you know."
    )
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes("First, you have")
    |> mes("to become a well")
    |> mes("experienced Swordman")
    |> mes("before you can consider")
    |> mes("becoming a Knight.")
    |> close()
  end

  defp ponder_offense_and_defense(ctx) do
    ctx
    |> mes("Offense and defense.")
    |> mes("Is there a way to have both without compromising one or the other?")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes("Two-handed weapons greatly")
    |> mes(
      "improve your offense but decrease your defenses. Is there something that can overcome this weakness?"
    )
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes("A weapon or some sort")
    |> mes("of technique like that")
    |> mes("would help Knights greatly...")
    |> close()
  end

  defp talk_about_test(ctx, quest) do
    cond do
      quest == 0 -> ponder_offense_and_defense(ctx)
      quest == 1 -> redirect_new_applicant(ctx)
      quest == 2 or quest == 3 -> redirect_to_sir_andrew(ctx)
      quest == 4 -> offer_knowledge_test(ctx)
      quest == 5 -> offer_knowledge_retest(ctx)
      quest == 6 -> redirect_to_sir_windsor(ctx)
      quest == 14 -> send_to_captain(ctx)
      true -> brush_off_busy(ctx)
    end
  end

  defp redirect_new_applicant(ctx) do
    {ctx, choice} =
      ctx
      |> ask_what_is_needed("Eh?")
      |> select(["I would like to take the test to change jobs.", "Oh, nothing."])

    if choice == 1 do
      applicant = if male?(ctx), do: "guy", else: "girl"

      ctx
      |> mes("[Sir Siracuse]")
      |> mes("Oh, to become")
      |> mes("a Knight? Come to")
      |> mes("think of it, aren't")
      |> mes("you the #{applicant} that")
      |> mes("just applied?")
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes("Let's see...")
      |> mes("Your name was")
      |> mes("#{char_name(ctx, 0)}.")
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes("But, before you come to me, you must visit the others. The way")
      |> mes("I see it, you haven't proven that you know the basics. But I'll")
      |> mes("reconsider once you")
      |> mes("pass the first test.")
      |> close()
    else
      shrug_off(ctx)
    end
  end

  defp redirect_to_sir_andrew(ctx) do
    {ctx, choice} =
      ctx
      |> ask_what_is_needed("Eh?")
      |> select(["I would like to take the test to change jobs.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Siracuse]")
      |> mes("Hahaha~!")
      |> mes(
        "Aren't you supposed to be taking Andrew's test? You can't just skip that, you know! All of our tests are important."
      )
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes("Speak to Sir Andrew first.")
      |> mes("My test for you will come after you've finished his test.")
      |> close()
    else
      shrug_off(ctx)
    end
  end

  defp offer_knowledge_test(ctx) do
    {ctx, choice} =
      ctx
      |> ask_what_is_needed("Oh?")
      |> select(["Sir Andrew sent me to take your test.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Siracuse]")
      |> mes(
        "I see, you've passed the first test. Very well, I'll make some time for you. Let me introduce myself. My name is James Siracuse."
      )
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes(
        "This test will measure how much you know about Knighthood. More importantly, I want to know your thoughts about honor."
      )
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes(
        "Don't be nervous, I won't keep you too long. These will be quick questions. Plus, you still have to see the others, right?"
      )
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes("Well then,")
      |> mes("let's begin.")
      |> mes("Please answer")
      |> mes("promptly.")
      |> next()
      |> ask_two_hand_quicken()
    else
      shrug_off(ctx)
    end
  end

  defp offer_knowledge_retest(ctx) do
    {ctx, choice} =
      ctx
      |> mes("What...")
      |> mes("You again?")
      |> next()
      |> select(["I wish to take the test again.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Siracuse]")
      |> mes("Is that right?")
      |> mes("Are you sure you're")
      |> mes("prepared this time?")
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes("Alright then,")
      |> mes("here we go again...")
      |> next()
      |> ask_two_hand_quicken()
    else
      shrug_off(ctx)
    end
  end

  defp ask_two_hand_quicken(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Siracuse]")
      |> mes(
        "A Knight must possess great strength, defense, speed, and the skill to wield a Two-Handed Sword. Which of the following weapons are not affected by the Two Hand Quicken skill?"
      )
      |> next()
      |> select(["Katana", "Slayer", "Broadsword", "Flamberge"])

    if choice != 4 do
      ctx
      |> fail_test()
      |> mes("Wrong!")
      |> mes("That's a Two-Handed Sword!")
      |> mes("Are you sure you want to be a Knight? You don't even know the basics...")
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes(
        "If you're not sure about anything, go into town and ask any Knight. You need to learn more about Knights before applying for the job!"
      )
      |> close()
    else
      ask_bowling_bash(ctx)
    end
  end

  defp ask_bowling_bash(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Siracuse]")
      |> mes(
        "Good, now let me ask about some skills. Which of the following is not necessary to learn Bowling Bash?"
      )
      |> next()
      |> select([
        "Two Handed Sword Mastery Lv.5",
        "Magnum Break Lv.3",
        "Provoke Lv.10",
        "Bash Lv.10"
      ])

    if choice != 3 do
      ctx
      |> fail_test()
      |> mes("Wrong!")
      |> mes(
        "You need that to learn Bowling Bash! You should learn more about the Knight class before applying for the job!"
      )
      |> close()
    else
      ask_brandish_spear(ctx)
    end
  end

  defp ask_brandish_spear(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Siracuse]")
      |> mes(
        "Knights can also use Spears, unlike other jobs, and have skills related to Spears as well. What skills are not necessary to learn the skill Brandish Spear?"
      )
      |> next()
      |> select([
        "Pierce Lv.5",
        "Spear Stab Lv.3",
        "Spear Boomerang Lv.3",
        "Peco Peco Ride Lv.1"
      ])

    if choice != 3 do
      ctx
      |> fail_test()
      |> mes(
        "Wrong! You need to learn that to learn Brandish Spear! How can you not know about Knights if you want to become one?"
      )
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes("If you aren't sure about anything, go into town and ask any Knight")
      |> mes("for help. Come back after you've learned more about Knights.")
      |> close()
    else
      ask_ghost_spear(ctx)
    end
  end

  defp ask_ghost_spear(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Siracuse]")
      |> mes(
        "Some Spears also have magical attributes, just like spells. Of the following, which can attack a Nightmare, which has the Ghost attribute?"
      )
      |> next()
      |> select(["Zephyrus", "Lance", "Bill Guisarme", "Crescent Scythe"])

    if choice != 1 do
      ctx
      |> fail_test()
      |> mes(
        "Wrong! You'll be doing absolutely no damage with that type of Spear! Come back after you've learned more about Knights!"
      )
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes(
        "If you have a question, just ask any Knight in town. This is basic knowledge for us!"
      )
      |> close()
    else
      ask_cavalier_mastery(ctx)
    end
  end

  defp ask_cavalier_mastery(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Siracuse]")
      |> mes(
        "When you become a Knight you can ride a Peco Peco. However, your attack speed decreases once you're mounted on a Peco Peco."
      )
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes(
        "But, you can counter this speed decrease as you learn the Cavalier Mastery skill. What percentage of your normal attack speed will you have after learning Level 3 Cavalier Mastery?"
      )
      |> next()
      |> select([
        "70 % of normal attack speed",
        "80 % of normal attack speed",
        "90 % of normal attack speed",
        "100 % of normal attack speed"
      ])

    if choice != 2 do
      ctx
      |> fail_test()
      |> mes("Wrong!")
      |> mes("Don't bother riding a Peco Peco if you don't know about Cavalier Mastery!")
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes("You better come back after you've learned a little more about Knights!")
      |> close()
    else
      ask_about_novices(ctx)
    end
  end

  defp ask_about_novices(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Siracuse]")
      |> mes("Good, good...")
      |> mes(
        "I'm pretty sure you know a decent amount about Knights. Now, let me ask you some personal questions about Knights."
      )
      |> next()
      |> mes("[Sir Siracuse]")
      |> mes("What should you do when you run into a Novice asking for help in town?")
      |> next()
      |> select([
        "Tell the Novice of a reasonable hunting area.",
        "Let the Novice fight while you take the damage.",
        "Give the Novice a bunch of Zeny and items."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Sir Siracuse]")
        |> mes(
          "Of course, even a Novice needs to learn how to be independent. Giving good guidance to Novices is one of the best things we can do."
        )
        |> next()
        |> ask_about_parties()

      2 ->
        ctx
        |> fail_test()
        |> mes(
          "You have the wrong idea. Do you really believe that is helping the Novice? Give a man a fish, he will eat for a day. Teach him to fish, he will eat for a lifetime!"
        )
        |> close()

      3 ->
        ctx
        |> fail_test()
        |> mes(
          "Do you really believe that this will truly help the poor Novice? It's generous but, they will not know the true value of zeny and items until they earn it themselves."
        )
        |> close()

      _ ->
        ask_about_parties(ctx)
    end
  end

  defp ask_about_parties(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Siracuse]")
      |> mes("Alright...")
      |> mes("Now, how should")
      |> mes("you act within")
      |> mes("a party?")
      |> next()
      |> select([
        "Protect everyone in the front of the battle.",
        "Gather monsters and destroy them at once.",
        "Get as many items possible, at all cost."
      ])

    case choice do
      1 ->
        ctx
        |> mes("[Sir Siracuse]")
        |> mes(
          "That's it! Our strength and attacks are very important in a party. All Knights should engage in a battle with that mindset."
        )
        |> next()
        |> ask_about_values()

      2 ->
        ctx
        |> fail_test()
        |> mes(
          "Are you crazy? Don't you realize the flaw in that kind of thinking? You can't control large mobs. What if they kill you? Who will protect the innocent?"
        )
        |> close()

      3 ->
        ctx
        |> fail_test()
        |> mes(
          "I see your greed and we will have none of it here! It seems you do not truly care for others!"
        )
        |> mes("Get lost!")
        |> close()

      _ ->
        ask_about_values(ctx)
    end
  end

  defp ask_about_values(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Sir Siracuse]")
      |> mes("Lastly...")
      |> mes("what's the most")
      |> mes("important value")
      |> mes("a Knight must have?")
      |> next()
      |> select(["Honor", "Wealth", "Status"])

    case choice do
      1 ->
        ctx
        |> mes("[Sir Siracuse]")
        |> mes(
          "Right, above all else, Knights must be honorable! We live and die for honor! Always keep that in mind."
        )
        |> next()
        |> pass_test()

      2 ->
        ctx
        |> fail_test()
        |> mes(
          "You're scum! You strive to become a Knight for personal wealth? Get lost! We will not accept someone like you in our Chivalry!"
        )
        |> close()

      3 ->
        ctx
        |> fail_test()
        |> mes(
          "So you're trying to become famous through the Chivalry? That's pathetic. We won't accept someone like you in our Chivalry!"
        )
        |> close()

      _ ->
        pass_test(ctx)
    end
  end

  defp pass_test(ctx) do
    ctx
    |> set_char_var(:KNIGHT_Q, 6)
    |> changequest(9003, 9004)
    |> mes("[Sir Siracuse]")
    |> mes("Well then,")
    |> mes("this is the")
    |> mes("end of my test.")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes("For your next")
    |> mes("test, please go")
    |> mes("see Sir Windsor.")
    |> mes("He's very quiet,")
    |> mes("but don't let that")
    |> mes("get to you.")
    |> close()
  end

  defp fail_test(ctx), do: ctx |> set_char_var(:KNIGHT_Q, 5) |> mes("[Sir Siracuse]")

  defp redirect_to_sir_windsor(ctx) do
    {ctx, choice} =
      ctx
      |> ask_what_is_needed("Oh?")
      |> select(["I would like to take the test to change jobs.", "Oh, nothing."])

    if choice == 1 do
      ctx
      |> mes("[Sir Siracuse]")
      |> mes("Hey...")
      |> mes(
        "You already took my test, didn't you? You're done here. You should go visit Sir Windsor now..."
      )
      |> close()
    else
      shrug_off(ctx)
    end
  end

  defp send_to_captain(ctx) do
    ctx
    |> mes("Mmm...?")
    |> mes("You finished")
    |> mes("everyone else's")
    |> mes("tests as well?")
    |> next()
    |> mes("[Sir Siracuse]")
    |> mes("Well then,")
    |> mes("go and see the")
    |> mes("captain. We'll all")
    |> mes("be there to evaluate")
    |> mes("your performance.")
    |> close()
  end

  defp brush_off_busy(ctx) do
    ctx
    |> mes("Hey again.")
    |> mes("Did you need something?")
    |> mes("Sorry, but I'm busy at the moment. You should go and finish the rest of your tests.")
    |> close()
  end

  defp ask_what_is_needed(ctx, greeting) do
    ctx
    |> mes(greeting)
    |> mes("Do you have")
    |> mes("something to")
    |> mes("ask me?")
    |> next()
  end

  defp shrug_off(ctx) do
    ctx
    |> mes("[Sir Siracuse]")
    |> mes("Hmmm...?")
    |> mes("Alright.")
    |> mes("It's just that")
    |> mes("you had that")
    |> mes("look on your")
    |> mes("face.")
    |> close()
  end

  defp male?(ctx), do: sex(ctx) == get_char_var(ctx, :SEX_MALE, 0)
end
