defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Sage.PracticalExaminationP do
  @moduledoc """
  Hermes Tris, the Sage academy professor who runs the practical examination and assigns
  each candidate's research subject.

  ## Behavior

  - Greets non-Mages with class-specific small talk.
  - Sends candidates who are ready for the practical examination into the test arena.
  - After a passed examination, randomly assigns Yggdrasil, monster, or elemental magic
    research and advances the quest.
  - Reminds candidates of their assigned professor or of the dean.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Unknown Translator
    - Darkchild
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "yuno_in03",
        x: 169,
        y: 180,
        dir: 3,
        sprite: 755,
        name: "Practical Examination P",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Hermes Tris]")

    if Rathena.job_id(base_job(ctx)) != Rathena.job_id(:mage) do
      ctx |> greet_non_mage() |> close()
    else
      talk_to_candidate(ctx, get_char_var(ctx, :SAGE_Q, 0))
    end
  end

  defp greet_non_mage(ctx) do
    cond do
      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:sage) ->
        ctx
        |> mes("Welcome. How have you been?")
        |> mes("I guess you've been through a lot of hard times...I can tell by your appearance.")
        |> next()
        |> mes("[Hermes Tris]")
        |> mes(
          "I know how hard it is to explore all those perilous areas, but it will help you to gain more knowledge."
        )
        |> mes("Book smarts never can beat street smarts.")
        |> next()
        |> mes("[Hermes Tris]")
        |> mes("However, it's a very dangerous idea to go deep inside a dungeon alone. ")
        |> mes("You'd better look for trustworthy comrades.")

      Rathena.job_id(base_job(ctx)) == Rathena.job_id(:novice) ->
        ctx
        |> mes("Heh heh, now ain't that a cute little Novice?")
        |> next()
        |> mes("[Hermes Tris]")
        |> mes(
          "In this continent of Rune-Midgarts, there are a lot of unknown places and objects that haven't been fully discovered."
        )
        |> mes("The monsters, mysterious objects and heroes of myths...")
        |> next()
        |> mes("[Hermes Tris]")
        |> mes("Why don't you consider being a Sage in the future?")
        |> mes("You will love studying the world.")
        |> next()
        |> mes("[Hermes Tris]")
        |> mes("If by chance you do decide to do that, we'll meet again.")
        |> mes("Take care, kiddy.")

      true ->
        ctx
        |> mes("Welcome to the Schweicherbil Magic Academy.")
        |> next()
        |> mes("[Hermes Tris]")
        |> mes("We Sages are more like scholars than Mages.")
        |> mes("We are very helpful and powerful as members of a party.")
        |> next()
        |> mes("[Hermes Tris]")
        |> mes("Try to make a party with a Sage next time.")
        |> mes("The wisdom a Sage will bring will be more than helpful for your party...")
    end
  end

  defp talk_to_candidate(ctx, quest) when quest >= 0 and quest <= 3 do
    ctx
    |> mes("I am Professor Hermes, in charge of practical examinations.")
    |> mes("Are you a candidate for the Sage class?")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("Register your application and take the written test first.")
    |> close()
  end

  defp talk_to_candidate(ctx, quest) when quest == 4 or quest == 5 do
    ctx
    |> mes("I am professor Hermes, in charge of practical examinations.")
    |> mes("Are you a candidate for the Sage class?")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("Go pass the written test with Professor Claytos first.")
    |> mes("Then I will take care of you.")
    |> close()
  end

  defp talk_to_candidate(ctx, 6) do
    {ctx, choice} =
      ctx
      |> mes("Welcome, you just passed the written test, didn't you?")
      |> mes("Now it's time for the practical examination.")
      |> next()
      |> mes("[Hermes Tris]")
      |> mes("There is nothing difficult or special about this test.")
      |> mes("All you have to do is kill all the monsters within the time limit.")
      |> next()
      |> mes("[Hermes Tris]")
      |> mes(
        "It's better to experience this for yourself, rather than be told about this test 100 times."
      )
      |> mes("How about it? Are you ready to take this test?")
      |> next()
      |> select(["Yes, I am.", "Sorry, give me some time."])

    ctx
    |> set_char_var(:SAGE_Q, 7)
    |> answer_readiness(choice)
  end

  defp talk_to_candidate(ctx, 7) do
    {ctx, choice} =
      ctx
      |> mes("Welcome again! So, did you fully prepare yourself this time?")
      |> mes("Oh well, it's not that hard. Give it your all, okay?")
      |> next()
      |> mes("[Hermes Tris]")
      |> mes("Are you ready?")
      |> next()
      |> select(["Yes, I am.", "Sorry, give me some time."])

    answer_readiness(ctx, choice)
  end

  defp talk_to_candidate(ctx, 8) do
    ctx
    |> mes("Good job~ Since you passed the practical examination as well...")
    |> mes("I'll accept your admission.")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("Now I need to decide what subject you will learn and study...")
    |> mes(
      "Let's see... let me check your written test grade and the time spent on the practical examination."
    )
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("Hmm, hmm... I see.")
    |> mes("Well... I think you're okay.")
    |> next()
    |> assign_subject(Enum.random(1..3))
  end

  defp talk_to_candidate(ctx, 9) do
    ctx
    |> mes("Huh? Didn't you understand what I said?")
    |> mes("I told you to study Yggdrasil.")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("Go ask for help from Professor Saphien. He's in the Lecture Room.")
    |> close()
  end

  defp talk_to_candidate(ctx, 11) do
    ctx
    |> mes("Huh? Didn't you understand what I said?")
    |> mes("I told you to study monsters.")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("Go ask for help from Professor Lucius. He's in the Monster Museum.")
    |> close()
  end

  defp talk_to_candidate(ctx, 13) do
    ctx
    |> mes("Huh? Didn't you understand what I said?")
    |> mes("I told you to study magic spells that possess certain properties.")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("Go ask a help from Professor Aebecee. He's in the Somatology Laboratory.")
    |> close()
  end

  defp talk_to_candidate(ctx, 15) do
    ctx
    |> mes("What are you doing here? Aren't you supposed to be with Dean Kayron?")
    |> mes("Oh well, there's no harm in showing me your dissertation though...")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("But then again, maybe there is. Go see Dean Kayron.")
    |> close()
  end

  defp talk_to_candidate(ctx, _quest) do
    ctx
    |> mes("Oh sorry, I'm quite busy at the moment...")
    |> mes("If you have any questions, go visit the professor I've assigned to you.")
    |> close()
  end

  defp answer_readiness(ctx, 1) do
    ctx
    |> mes("[Hermes Tris]")
    |> mes("Good, let's start immediately.")
    |> mes("Do your best and come back safely!")
    |> close()
    |> warp("job_sage", 50, 154)
  end

  defp answer_readiness(ctx, _choice) do
    ctx
    |> mes("[Hermes Tris]")
    |> mes("Yes, you don't need to hurry... take your time and come back.")
    |> close()
  end

  defp assign_subject(ctx, 1) do
    ctx
    |> set_char_var(:SAGE_Q, 9)
    |> changequest(2046, 2047)
    |> mes("[Hermes Tris]")
    |> mes("Now, you will study Yggdrasil.")
    |> mes("Yggdrasil is the tree that was rumored to be the source of life for this world.")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes(
      "That is a good subject which helps us to recognize changes in the world, as well as the direction of its improvement."
    )
    |> mes("Go ask for help from Professor Saphien. He's in the Lecture Room.")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("I wish you luck.")
    |> close()
  end

  defp assign_subject(ctx, 2) do
    ctx
    |> set_char_var(:SAGE_Q, 11)
    |> changequest(2046, 2048)
    |> mes("[Hermes Tris]")
    |> mes("Now, you will study monsters.")
    |> mes(
      "The purpose of this study is to learn and understand more about creatures existing all over the continent."
    )
    |> next()
    |> mes("[Hermes Tris]")
    |> mes(
      "This is a good subject which will help you lead your life as a well-experienced Sage."
    )
    |> mes("Go ask for help from Professor Lucius. He's in the Monster Museum.")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("I wish you luck.")
    |> close()
  end

  defp assign_subject(ctx, 3) do
    ctx
    |> set_char_var(:SAGE_Q, 13)
    |> changequest(2046, 2049)
    |> mes("[Hermes Tris]")
    |> mes("Now, you will study magic skills that have certain properties.")
    |> mes(
      "The purpose of this study is to better understand basic magic skills that we use in everyday life."
    )
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("That is a good subject which helps you to deeply understand of the truth of magic.")
    |> mes("Go ask Professor Aebecee for help...He's in the Somatology Laboratory.")
    |> next()
    |> mes("[Hermes Tris]")
    |> mes("I wish you luck.")
    |> close()
  end
end
