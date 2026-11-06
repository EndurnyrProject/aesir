defmodule Aesir.ZoneServer.Content.Npc.Floating.SeniorCrusader do
  @moduledoc """
  Michael Halig, leader of the Prontera Chivalry and start of the Crusader job
  change quest.

  ## Behavior

  - Turns away babies, Crusaders, Novices and other classes with their own
    lines, and explains the Chivalry to a Swordsman who has not applied yet.
  - Accepts an application from a Swordsman of at least Job Level 40 with no
    unused skill points, and starts one of three item-gathering tasks at random
    (`CRUS_Q` 1 to 3, quests 3006 to 3008).
  - A Swordsman who already carries the Chivalry Emblem and the Hand of God is
    sent straight to Moorenak Mijoul instead: the items are taken and `CRUS_Q`
    set to 4.
  - Collects the ten items of each task, advances the quest to 3009 and sends
    the player on to Moorenak Mijoul.
  - On step 10, changes the job to Crusader, clears the job variables and hands
    out the awakening potions: twelve for a Job Level 50 applicant, six
    otherwise.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Black Dragon
    - Shin
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - Lupus
    - yyCC
    - Kisuka
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-2/crusader.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_cas",
        x: 251,
        y: 75,
        dir: 1,
        sprite: 752,
        name: "Senior Crusader",
        scope: :renewal
      },
      %{
        map: "prt_castle",
        x: 45,
        y: 169,
        dir: 5,
        sprite: 752,
        name: "Senior Crusader",
        scope: :pre_renewal
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FClearjobvar
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @emblem 1004
  @hand_of_god 1009
  @potion 504

  @tasks %{
    1 => %{quest: 3006, items: [957, 959, 1099, 901]},
    2 => %{quest: 3007, items: [932, 1043, 1098, 1094]},
    3 => %{quest: 3008, items: [958, 930, 1041, 1062]}
  }

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Michael Halig]")
    job = Rathena.job_id(base_job(ctx))
    quest = get_char_var(ctx, :CRUS_Q, 0)

    cond do
      upper(ctx) == 1 -> turn_away_baby(ctx)
      job != Rathena.job_id(:swordman) -> turn_away(ctx, job)
      quest <= 3 and called?(ctx) -> called_to_crusader(ctx, false)
      quest == 0 -> class_intro(ctx)
      quest in 1..3 -> item_task(ctx, quest)
      quest == 10 -> become_crusader(ctx)
      true -> pending_lines(ctx)
    end
  end

  defp called?(ctx) do
    Rathena.truthy?(count_item(ctx, @emblem)) and Rathena.truthy?(count_item(ctx, @hand_of_god))
  end

  defp turn_away_baby(ctx) do
    ctx
    |> mes(
      "Go and train yourself in preparation for the holy war that is coming. Victory will be in the hands of those who are most ready to receive it."
    )
    |> next()
    |> mes("[Michael Halig]")
    |> mes("You don't belong here, my friend.")
    |> mes("Be advised to continue practicing yourself.")
    |> close()
  end

  defp turn_away(ctx, job) do
    cond do
      job == Rathena.job_id(:crusader) ->
        ctx
        |> mes(
          "Go and train yourself in preparation for the holy war that is coming. Victory will be in the hands of those who are most ready to receive it."
        )
        |> next()
        |> mes("[Michael Halig]")
        |> mes(
          "Chaos will one day arise to challenge our principles of peace, justice and order. Until we have eliminated evil and created our ideal world, we must not cease training."
        )
        |> close()

      job == Rathena.job_id(:novice) ->
        ctx
        |> mes("We are Crusaders,")
        |> mes("warriors preparing")
        |> mes("to fight in the Holy War.")
        |> next()
        |> mes("[Michael Halig]")
        |> mes(
          "If you wish to join us, you must first learn the Swordsman discipline and train yourself thoroughly..."
        )
        |> close()

      true ->
        ctx
        |> mes("We are Crusaders,")
        |> mes("warriors preparing")
        |> mes("to fight in the Holy War.")
        |> next()
        |> mes("[Michael Halig]")
        |> mes(
          "As it happened one thousand years ago, evil forces will one day attack in droves in an attempt to take over the world once again."
        )
        |> close()
    end
  end

  defp called_to_crusader(ctx, set_quest?) do
    ctx =
      ctx
      |> mes("Ah...")
      |> mes(
        "I see that you have been called to become a Crusader. We are assured of your will, but now we must test your capabilities."
      )
      |> next()
      |> mes("[Michael Halig]")
      |> mes(
        "Meet with Moorenak Miyol who is training in the underground dungeon of the Prontera Castle. Go, and speak with him first."
      )
      |> next()
      |> delitem(@emblem, 1)
      |> delitem(@hand_of_god, 1)
      |> set_char_var(:CRUS_Q, 4)

    ctx = if set_quest?, do: setquest(ctx, 3009), else: ctx

    ctx
    |> mes("[Michael Halig]")
    |> mes(
      "Moorenak and others like him will test the limits of your capabilities and help you find your path. Return to me after you have completed their tests..."
    )
    |> close()
  end

  defp class_intro(ctx) do
    {ctx, answer} =
      ctx
      |> mes("We are Crusaders, warriors preparing for the Holy War.")
      |> mes("What brings you")
      |> mes("to this place?")
      |> next()
      |> select(["I want to prepare for the Holy War!", "Nothing in particular."])

    if answer == 1, do: apply_to_join(ctx), else: not_interested(ctx)
  end

  defp not_interested(ctx) do
    ctx = mes(ctx, "[Michael Halig]")

    ctx =
      if sex(ctx) == 1 do
        mes(
          ctx,
          "If you, too, are a man of the sword, constantly train and prepare yourself. No one knows when the Holy War may begin."
        )
      else
        mes(
          ctx,
          "As a woman of the sword, you must train diligently and constantly. Prepare yourself, for no one knows when the Holy War may be coming."
        )
      end

    close(ctx)
  end

  defp apply_to_join(ctx) do
    {ctx, answer} =
      ctx
      |> mes("[Michael Halig]")
      |> mes("You wish to become")
      |> mes("a Crusader...?")
      |> mes("Joining us is not as")
      |> mes("easy as it sounds.")
      |> next()
      |> mes("[Michael Halig]")
      |> mes(
        "I am Michael Halig. I am one of but many Crusaders preparing for the Holy War. We continuously train ourselves with sincere faith and endless loyalty."
      )
      |> next()
      |> mes("[Michael Halig]")
      |> mes(
        "We recruit Swordsmen that express exceptional faith, or those who were born as warriors"
      )
      |> mes("by Odin's will.")
      |> next()
      |> mes("[Michael Halig]")
      |> mes(
        "Possessing the ^3355FFChivalry Emblem^000000 and ^3355FFHand of God^000000 is seen as a sign that you have been called to become a Crusader."
      )
      |> next()
      |> mes("[Michael Halig]")
      |> mes("After obtaining those items and passing our tests, you too, can become a Crusader.")
      |> next()
      |> mes("[Michael Halig]")
      |> mes("I don't know what type of person you are right now though. But")
      |> mes(
        "I shall test you if you desire. Are you willing to endure these tests in preparation for the Holy War?"
      )
      |> next()
      |> select(["Yes, I do.", "I'd like to think about it."])

    if answer == 1, do: accept_application(ctx), else: think_about_it(ctx)
  end

  defp think_about_it(ctx) do
    ctx
    |> mes("[Michael Halig]")
    |> mes(
      "Nobody knows when the Holy War will come. We must prepare in advance and cannot afford to slacken"
    )
    |> mes("our training.")
    |> next()
    |> mes("[Michael Halig]")
    |> mes(
      "If you feel that participating in the Holy War is your calling, please come back right away and take the test to become"
    )
    |> mes("a Crusader.")
    |> close()
  end

  defp accept_application(ctx) do
    cond do
      job_level(ctx) < 40 ->
        ctx
        |> mes("[Michael Halig]")
        |> mes("Wait...")
        |> mes("You're not ready yet.")
        |> mes("You need to be at least")
        |> mes("Job Level 40 to become")
        |> mes("a Crusader.")
        |> next()
        |> mes("[Michael Halig]")
        |> mes(
          "Train yourself more as a Swordsman and wait for your calling. I understand your intent, but as of now, you cannot join us."
        )
        |> close()

      Rathena.truthy?(skill_point(ctx)) ->
        ctx
        |> mes("[Michael Halig]")
        |> mes(
          "You haven't finished learning everything as a Swordsman. Use all of your remaining skill points, and then return to me."
        )
        |> close()

      true ->
        start_application(ctx)
    end
  end

  defp start_application(ctx) do
    ctx =
      ctx
      |> mes("[Michael Halig]")
      |> mes("Then...")
      |> mes("I shall test you to see if you are fit to become a Crusader.")
      |> next()
      |> mes("[Michael Halig]")
      |> mes("Your name is")
      |> mes(char_name(ctx, 0) <> "...?")
      |> mes("Let's see...")
      |> next()

    if called?(ctx), do: called_to_crusader(ctx, true), else: choose_item_task(ctx)
  end

  defp choose_item_task(ctx) do
    ctx =
      ctx
      |> mes("[Michael Halig]")
      |> mes(
        "Mmm. I can't discern whether or not you have the heart to become a Crusader. However, if you have the will and put forth the effort, you may have what it takes."
      )
      |> next()
      |> mes("[Michael Halig]")
      |> mes("Now...")
      |> mes(
        "This is my test for you. Bring me the following items and prove your determination to me."
      )
      |> next()
      |> mes("[Michael Halig]")

    task = Enum.random(1..3)
    %{quest: quest, items: items} = Map.fetch!(@tasks, task)

    ctx
    |> set_char_var(:CRUS_Q, task)
    |> setquest(quest)
    |> describe_items(items)
    |> next()
    |> mes("[Michael Halig]")
    |> mes(
      "Show me the strength of your will by gathering these items. If you prove successful, you will progress to the next test. May Odin protect you."
    )
    |> close()
  end

  defp item_task(ctx, quest) do
    %{items: items} = Map.fetch!(@tasks, quest)

    ctx =
      ctx
      |> mes(
        "Have you proven your determination with the task I have given you, or do you possess the items proving that you have received your calling?"
      )
      |> next()

    if Enum.all?(items, &(count_item(ctx, &1) > 9)) do
      collect_items(ctx, items)
    else
      remind_items(ctx, items)
    end
  end

  defp collect_items(ctx, [first, second, third, fourth]) do
    ctx =
      ctx
      |> mes("[Michael Halig]")
      |> mes("Ah, well done.")
      |> mes(
        "I must acknowledge your efforts and determination. You may now proceed to take the next test."
      )
      |> next()
      |> mes("[Michael Halig]")
      |> mes(
        "Meet with Moorenak Miyol who is training in the underground dungeon of the Prontera Castle. Go, and speak with him first."
      )
      |> next()
      |> delitem(first, 10)
      |> delitem(second, 10)
      |> delitem(third, 10)
      |> delitem(fourth, 10)
      |> set_char_var(:CRUS_Q, 4)

    ctx =
      cond do
        checkquest(ctx, 3006) != -1 -> changequest(ctx, 3006, 3009)
        checkquest(ctx, 3007) != -1 -> changequest(ctx, 3007, 3009)
        true -> changequest(ctx, 3008, 3009)
      end

    ctx
    |> mes("[Michael Halig]")
    |> mes(
      "Moorenak and others like him will test the limits of your capabilities and help you find your path. Return to me after you have completed their tests..."
    )
    |> close()
  end

  defp remind_items(ctx, items) do
    ctx
    |> mes("[Michael Halig]")
    |> mes(
      "Ah, you still have not completed the task I have given to you. Bring me the following items, and prove your will to become a Crusader to me..."
    )
    |> next()
    |> mes("[Michael Halig]")
    |> describe_items(items)
    |> next()
    |> mes("[Michael Halig]")
    |> mes(
      "If you put forth the effort, you'll be able to accomplish this task. May Odin protect you on your journeys."
    )
    |> close()
  end

  defp become_crusader(ctx) do
    if Rathena.truthy?(skill_point(ctx)) do
      ctx
      |> mes(
        "You haven't finished learning everything as a Swordsman. Use all of your remaining skill points, and then return to me."
      )
      |> close()
    else
      promote(ctx)
    end
  end

  defp promote(ctx) do
    ctx =
      ctx
      |> mes(
        "Congratulations on completing all of your tests. You are truly worthy of fighting alongside side us in the Holy War as a Crusader."
      )
      |> next()
      |> mes("[Michael Halig]")
      |> mes("Together, let us ready ourselves and be victorious over evil and tyranny!")
      |> next()

    job_level = job_level(ctx)

    {ctx, _} =
      ctx
      |> completequest(3015)
      |> jobchange(:crusader)
      |> FClearjobvar.call([])

    ctx =
      ctx
      |> mes("[Michael Halig]")
      |> mes("Behold...!")
      |> mes("You are now a Crusader!")
      |> mes("When the Holy War comes, we shall fight side by side against the forces of evil.")
      |> next()
      |> mes("[Michael Halig]")
      |> mes("Now you are")
      |> mes("one of us!")

    ctx =
      if sex(ctx) == 1 do
        mes(ctx, "...Brother.")
      else
        mes(ctx, "...Comrade.")
      end

    ctx = next(ctx)

    ctx =
      if job_level != 50 do
        give_item(ctx, @potion, 6)
      else
        give_item(ctx, @potion, 12)
      end

    ctx
    |> mes("[Michael Halig]")
    |> mes(
      "And use this in times of dire peril. It will give you strength when your wounds are most grievous."
    )
    |> next()
    |> mes("[Michael Halig]")
    |> mes(
      "Never forget that the Holy War is approaching. We must be prepare for the inevitable tide of evil that will sweep this world. Now, go forth and fight for the principles of freedom and justice!"
    )
    |> close()
  end

  defp pending_lines(ctx) do
    ctx
    |> mes(
      "It seems that you have not yet completed all of the testing. You will not be ready to become a Crusader until you have completed the tests set before you."
    )
    |> next()
    |> mes("[Michael Halig]")
    |> mes(
      "Return to me when you have completed all of your tests. When you finally prove eligible, you will join the proud ranks of the mighty Crusaders."
    )
    |> close()
  end

  defp describe_items(ctx, items) do
    Enum.reduce(items, ctx, fn item, ctx ->
      mes(ctx, "10 ^3355FF" <> Rathena.getitemname(item) <> "^000000")
    end)
  end
end
