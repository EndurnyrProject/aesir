defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Munkenro230197 do
  @moduledoc """
  Munkenro at the rift's far side, who puts a proven adventurer through the alliance's own
  survival test.

  ## Behavior

  - At `ep13_ryu` step 100 offers to send the player on to Ash-Vacuum, warping to the camp.
  - At step 20 introduces himself as Sikaiz's replacement and announces the survival test,
    advancing quest 10076 to 10077 and setting the step to 21.
  - At step 21 starts the test on a two-option menu: confirming sets the step to 22, moves quest
    10077 to 10078 and enables the alliance head's assault; hesitating counts as a refusal.
  - While `$@ep13_test` is 1 the other adventurers are being tested, and when it is 2 the player
    failed and gets one more chance.
  - Once `$@ep13_test` is back to 0 on step 22 the test is passed: quest 10078 completes, the
    step becomes 100 and the mode's experience reward is paid.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild22b",
        x: 230,
        y: 197,
        dir: 5,
        sprite: 967,
        name: "Munkenro",
        scope: :shared,
        unique_name: "Munkenro#2"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_ryu, 0) == 100 ->
        discover_gate(ctx)

      get_char_var(ctx, :ep13_ryu, 0) == 20 ->
        introduction(ctx)

      get_char_var(ctx, :ep13_ryu, 0) == 21 ->
        ready_menu(ctx)

      get_server_temp_var(ctx, "ep13_test", 0) == 2 ->
        failed_test(ctx)

      get_server_temp_var(ctx, "ep13_test", 0) == 1 ->
        testing_others(ctx)

      get_server_temp_var(ctx, "ep13_test", 0) == 0 and get_char_var(ctx, :ep13_ryu, 0) == 22 ->
        passed_test(ctx)

      true ->
        ctx
    end
  end

  defp discover_gate(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Munkenro]")
      |> mes("Are you ready to discover Ash-Vacuum?")
      |> next()
      |> select(["Yes, of course!", "Please, wait..."])

    case choice do
      1 -> sends_to_ash_vacuum(ctx)
      2 -> ctx |> mes("[Munkenro]") |> mes("Go prepare.") |> close()
      _ -> ctx
    end
  end

  defp sends_to_ash_vacuum(ctx) do
    ctx
    |> mes("[Munkenro]")
    |> mes("I wish you good luck!")
    |> mes("I hope you are successful in your adventures in Ash-Vacuum!")
    |> next()
    |> mes("[Munkenro]")
    |> mes("(...I just follow your lead!)")
    |> mes("(I remember you're strong-willed.)")
    |> mes("(Though I am guilty,)")
    |> mes("(I will do my best.)")
    |> close()
    |> warp("mid_camp", 210, 291)
  end

  defp introduction(ctx) do
    ctx =
      ctx
      |> mes("[Munkenro]")
      |> mes(
        "I am the head of the Three Kingdoms Alliance. You've come here for the discovery of the dimensional rift. Am I right?"
      )
      |> next()
      |> mes("[Munkenro]")
      |> mes("Um. You're the one that")
      |> mes("did some favors before...")

    ctx =
      ctx
      |> mes("Your name is #{char_name(ctx, 0)}?")
      |> mes("I remember you.")
      |> next()
      |> mes("[Munkenro]")
      |> mes("Sikaiz retired from his position urgently. I am his replacement.")
      |> next()
      |> mes("[Munkenro]")
      |> mes(
        "You don't need to know in detail all about it now. That's not important to you. Is it?"
      )
      |> next()

    ctx
    |> mes("[Munkenro]")
    |> mes(
      "You are here for the discovery of the dimensional rift. I can't send you there right away. I know that you've passed your tests, but that's the past. You have not been tested by me. ~"
    )
    |> next()
    |> mes("[Munkenro]")
    |> mes(
      "So you need to be tested again. I don't have too much time to test you now. So let's just do a short test."
    )
    |> next()
    |> mes("[Munkenro]")
    |> mes(
      "Now the soldiers here will start to attack you... If you survive, I will approve of you. Just do it in good time."
    )
    |> next()
    |> mes("[Munkenro]")
    |> mes("This can prove that you're strong enough. That's the minimum test I can perform.")
    |> next()
    |> changequest(10076, 10077)
    |> set_char_var(:ep13_ryu, 21)
    |> mes("[Munkenro]")
    |> mes("Once you get ready,")
    |> mes("just let me know.")
    |> close()
  end

  defp ready_menu(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Munkenro]")
      |> mes("Are you ready??")
      |> mes("Let's start!")
      |> next()
      |> select(["Ready!!", "Please, wait..."])

    case choice do
      1 -> start_the_test(ctx)
      2 -> hesitates(ctx)
      _ -> ctx
    end
  end

  defp start_the_test(ctx) do
    ctx =
      ctx
      |> mes("[Munkenro]")
      |> mes("Ok, just have a good adventure.")
      |> next()
      |> set_char_var(:ep13_ryu, 22)

    ctx =
      if isbegin_quest(ctx, 10077) == 1 do
        changequest(ctx, 10077, 10078)
      else
        ctx
      end

    ctx
    |> donpcevent("Head of the Alliance#moo::OnEnable")
    |> mes("[Munkenro]")
    |> mes("If you are too late,")
    |> mes("it will be considered as a failure, so come back soon.")
    |> close()
  end

  defp hesitates(ctx) do
    ctx
    |> mes("[Munkenro]")
    |> mes("If you hesitate,")
    |> mes("it means you fail.")
    |> mes("I will give you one more chance. Go ahead.")
    |> close()
  end

  defp failed_test(ctx) do
    ctx
    |> mes("[Munkenro]")
    |> mes("You're quite shrewd...")
    |> mes("How come you passed the test")
    |> mes("before? I can't believe this.")
    |> next()
    |> mes("[Munkenro]")
    |> mes("I will give you one more chance.")
    |> mes("Don't make any mistakes again.")
    |> next()
    |> set_char_var(:ep13_ryu, 21)
    |> set_server_temp_var("ep13_test", 0)
    |> mes("[Munkenro]")
    |> mes("Once you get ready,")
    |> mes("just let me know,")
    |> mes("to start!")
    |> close()
  end

  defp testing_others(ctx) do
    ctx
    |> mes("[Munkenro]")
    |> mes(
      "We are testing the other adventurers, so unless you have any business with me, visit me later."
    )
    |> close()
  end

  defp passed_test(ctx) do
    ctx =
      ctx
      |> mes("[Munkenro]")
      |> mes("Good! You did a good job!")
      |> mes("Though we didn't get enough time to test, I think it's almost perfect.")
      |> next()
      |> mes("[Munkenro]")
      |> mes(
        "You can feel I am too strict... I'm just doing what I need to do as head of the Alliance."
      )
      |> next()
      |> mes("[Munkenro]")
      |> mes(
        "If I can't manage the alliance well, I will feel guilty, that I am not doing Sikaiz's job any justice. Anyway, I will do my best."
      )
      |> next()
      |> mes("[Munkenro]")
      |> mes("Huh? I'm just whining.")
      |> mes("You don't need to hear this.")
      |> mes("Just forget it.")
      |> next()
      |> completequest(10078)
      |> set_char_var(:ep13_ryu, 100)

    ctx
    |> award_exp()
    |> mes("[Munkenro]")
    |> mes("I will let you go there.")
    |> mes("Let me know once you are ready.")
    |> close()
  end

  # The reference pays the smaller reward when `checkre(3)` reports renewal content.
  defp award_exp(ctx) do
    if Rathena.truthy?(checkre(ctx, 3)) do
      getexp(ctx, 66_000, 21_000)
    else
      getexp(ctx, 660_000, 210_000)
    end
  end
end
