defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.StaffOfficerAbidal do
  @moduledoc """
  Staff Officer Abidal briefs adventurers on the Midgard Expedition and helps restore its lost report.

  ## Behavior

  - Explains the expedition, its achievements, and the dangers of the Ash-Vacuum.
  - Offers the report delivery mission, advances quest 3085 to 3086 on acceptance, and
    directs the adventurer to the commander through the mission's early stages.
  - Starts report restoration at steps 61 and 62, advancing quest 3089 to 3090 and the
    step to 71 or 72 respectively.
  - Takes lost report pages in batches of ten, randomly restoring one of four volumes
    or consuming pages from duplicate or mismatched volumes; the odds depend on the step.
  - Reports which volumes have been restored and binds exactly one of each into the
    Expedition Report, setting step 8 and quest 3092 and erasing started quests 3090 and 3091.
  - Thanks returning adventurers or directs them onward as their mission progresses.

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
        map: "mid_campin",
        x: 94,
        y: 118,
        dir: 3,
        sprite: 755,
        name: "Staff Officer Abidal",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :ep13_1_edq, 0) == 13 or get_char_var(ctx, :ep13_1_edq, 0) == 14 ->
        thanks_for_the_mission(ctx)

      get_char_var(ctx, :ep13_1_edq, 0) == 0 ->
        offers_information(ctx)

      get_char_var(ctx, :ep13_1_edq, 0) == 1 ->
        offers_the_mission(ctx)

      get_char_var(ctx, :ep13_1_edq, 0) == 2 ->
        refers_to_the_commander(ctx)

      get_char_var(ctx, :ep13_1_edq, 0) == 3 ->
        wishes_a_safe_return(ctx)

      get_char_var(ctx, :ep13_1_edq, 0) == 4 or get_char_var(ctx, :ep13_1_edq, 0) == 5 ->
        asks_to_report_the_incident(ctx)

      get_char_var(ctx, :ep13_1_edq, 0) == 61 ->
        explains_restoration(ctx, 71)

      get_char_var(ctx, :ep13_1_edq, 0) == 62 ->
        explains_restoration(ctx, 72)

      get_char_var(ctx, :ep13_1_edq, 0) == 71 or get_char_var(ctx, :ep13_1_edq, 0) == 72 ->
        offers_restoration(ctx)

      get_char_var(ctx, :ep13_1_edq, 0) == 8 or
          (get_char_var(ctx, :ep13_1_edq, 0) > 8 and get_char_var(ctx, :ep13_1_edq, 0) < 13) ->
        resumes_the_mission(ctx)

      get_char_var(ctx, :ins_nyd, 0) > 0 ->
        mentions_the_new_duty(ctx)

      true ->
        greets_the_adventurer(ctx)
    end
  end

  defp thanks_for_the_mission(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes("Phew, I'm glad the mission is over. Thank you so much for your help.")
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "We'll contact you again when we have another mission for you. I hope we can count on your help again when the time comes."
    )
    |> close()
  end

  defp offers_information(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Staff Officer Abidal]")
      |> mes("I'm Staff Officer Abidal of the Midgard Expedition. How may I help you?")
      |> next()
      |> select([
        "Midgard Expedition Introduction",
        "Midgard Expedition's Achievement",
        "Situation in the Ash-Vacuum",
        "Quit"
      ])

    case choice do
      1 -> introduces_the_expedition(ctx)
      2 -> describes_achievements(ctx)
      3 -> describes_the_ash_vacuum(ctx)
      4 -> close(ctx)
      _ -> ctx
    end
  end

  defp introduces_the_expedition(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "The Midgard Expedition is conducted by a group of explorers from the three countries of Midgard and the Mercenary Association. We're here to explore the Ash-Vacuum."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Command Hibba Agip behind me is our commander. He may appear unreliable, but he has extensive knowledge and experience in exploration."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes("We have many aides and scholars to support our expedition.")
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Oh, you may know this already, but Commander Agip isn't from any of the three countries. Neither am I or Instructor Igrid."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "There's an obvious power struggle among the three countries to assign their officers to the commander position."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "As a last resort, they had to select Commander Agip since he's unaffiliated with any of those countries, but is talented enough to lead the expedition."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "We, the commanders, Igrid, and I aren't used to the leadership role. We're having trouble taking care of everything that's happening. *Sigh*"
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "The members of the Midgard Expedition are conducting various kinds of research about the Ash-Vacuum searching for possible living creatures and studying what might be beneficial for the development of the mainland."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "If you look around, you'll find many people in need of your help. Enjoy your stay in the otherworld, and feel free to ask me if you have questions."
    )
    |> close()
  end

  defp describes_achievements(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "We're still at an early stage of the expedition, so we haven't made any major achievements. That's why we need help from adventurers like you."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "If you look around this camp, you'll find many opportunities to help us. We always welcome every bit of help."
    )
    |> close()
  end

  defp describes_the_ash_vacuum(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes("So far, only a few truths about the Ash-Vacuum have been revealed.")
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "We now know there's a demihuman race in this otherworld, but we're too busy figuring out the true nature of the time-space gap, let alone study the demihuman race in depth."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "My advice for you will be to be careful when you encounter members of that race. Who knows? They might be extremely hostile toward other races."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Oh, and take heed, unidentified creatures appear outside the camp during nighttime. Be careful of them, too."
    )
    |> close()
  end

  defp offers_the_mission(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Staff Officer Abidal]")
      |> mes(
        "Oh, welcome back. I apologize for troubling you like this. I didn't feel to comfortable talking to you back there."
      )
      |> next()
      |> mes("[Staff Officer Abidal]")
      |> mes(
        "In fact, I have a favor to ask of you. From what I know of your accomplishments you're the right person for this."
      )
      |> next()
      |> mes("[Staff Officer Abidal]")
      |> mes(
        "On behalf of the expedition, I'd like to give you a mission. Would you like to accept it?"
      )
      |> next()
      |> select(["Yes.", "No."])

    case choice do
      1 -> assigns_the_mission(ctx)
      2 -> asks_to_reconsider(ctx)
      _ -> ctx
    end
  end

  defp assigns_the_mission(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Thank you so much. I had a good feeling about you, and I was so sure that you'd be willing to help."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Let's cut to the chase. The mission is simple, deliver our expedition report to the three countries of Midgard."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "But I have to tell you... We sent out three adventurers on this mission before you, and they all dissapeared. Please don't disclose this information to anyone."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "The commander or I cannot leave this camp, even though delivering the report is one of our most important duties. That's why I need someone reliable and trustworthy like you."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Phew, I'm so glad that you've accepted this mission. Now, please go receive the report from the commander. He'll officially assign you to the mission."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes("I'll prepare for your departure.")
    |> mes("Please go speak to the commander.")
    |> set_char_var(:ep13_1_edq, 2)
    |> changequest(3085, 3086)
    |> close()
  end

  defp asks_to_reconsider(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes("Oh, I see... Then can you help me whenever you have some time?")
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes("This is urgent, please think it over and come back if you change your mind.")
    |> close()
  end

  defp refers_to_the_commander(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes("I've reported to the commander about your decision to help us.")
    |> mes("Please go speak to him.")
    |> close()
  end

  defp wishes_a_safe_return(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "You've been assinged to the mission officially. Good luck, and I hope you'll come back safely."
    )
    |> close()
  end

  defp asks_to_report_the_incident(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes("I've heard the story. Why don't you go speak to the commander first?")
    |> close()
  end

  defp explains_restoration(ctx, step) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "It's as what the commander said. I still remember the contents of the report, even though it might not all be accurate without any references."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "If you bring me the pages of the lost report, I'll fill the missing parts and be able to complete the report again."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Why don't you go check the site of the accident? You might find some clues of their whereabouts. and..."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "This is my opinion, but otherworldly creatures might have taken an interest in the pages."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "I'm thinking this because the report contains information about the ecology of the otherworldly creatures. It's also made of paper and ink, materials from the mainland that might seem interesting to those creatures."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Anyways, please bring the pages of the report in ^0000FFincrements of 10^000000 whenever you find them. I'll try to put them in order."
    )
    |> set_char_var(:ep13_1_edq, step)
    |> changequest(3089, 3090)
    |> close()
  end

  defp offers_restoration(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Staff Officer Abidal]")
      |> mes("How have you been doing with finding the report's lost pages?")
      |> mes("Feel free to tell me whenever you're ready.")
      |> next()
      |> select([
        "Submit found pages.",
        "Check the report's resoration status.",
        "Quit."
      ])

    case choice do
      1 -> submits_pages(ctx)
      2 -> checks_restoration(ctx)
      3 -> close(ctx)
      _ -> ctx
    end
  end

  defp submits_pages(ctx) do
    if count_item(ctx, 11_013) > 0 and count_item(ctx, 11_014) > 0 and
         count_item(ctx, 11_015) > 0 and count_item(ctx, 11_016) > 0 do
      ctx
      |> mes("[Staff Officer Abidal]")
      |> mes("Oh, you've collected enough pages...")
      |> next()
      |> mes("[Staff Officer Abidal]")
      |> mes("Why don't you check the report's restoration status again?")
      |> close()
    else
      ctx =
        ctx
        |> mes("[Staff Officer Abidal]")
        |> mes(
          "Have you brought me pages of the lost report? Please bring them to me in increments of 10."
        )
        |> next()

      if count_item(ctx, 6040) > 9 do
        ctx =
          ctx
          |> mes("[Staff Officer Abidal]")
          |> mes("Thank you. Let me try to put them in order.")
          |> next()

        cond do
          get_char_var(ctx, :ep13_1_edq, 0) == 71 -> orders_pages(ctx, 71)
          get_char_var(ctx, :ep13_1_edq, 0) == 72 -> orders_pages(ctx, 72)
          true -> checks_restoration(ctx)
        end
      else
        ctx
        |> mes("[Staff Officer Abidal]")
        |> mes("You didn't bring enough pages, please bring them to me in increments of 10.")
        |> close()
      end
    end
  end

  defp orders_pages(ctx, step) do
    rolls = if step == 71, do: 1..7, else: 1..5

    ctx =
      ctx
      |> mes("[Staff Officer Abidal]")
      |> mes("Umm... This page should go here and..")
      |> next()
      |> set_local(:ep13_edq_wrong, Enum.random(rolls))

    case {step, get_local(ctx, :ep13_edq_wrong, 0)} do
      {71, 1} -> restores_volume(ctx, 11_013, "first", step)
      {71, roll} when roll in [3, 2] -> restores_volume(ctx, 11_014, "second", step)
      {71, roll} when roll in [5, 6] -> restores_volume(ctx, 11_015, "third", step)
      {71, 7} -> restores_volume(ctx, 11_016, "fourth", step)
      {72, 1} -> restores_volume(ctx, 11_013, "first", step)
      {72, 2} -> restores_volume(ctx, 11_014, "second", step)
      {72, roll} when roll in [3, 4] -> restores_volume(ctx, 11_015, "third", step)
      {72, 5} -> restores_volume(ctx, 11_016, "fourth", step)
      _ -> mismatched_pages(ctx, step)
    end
  end

  defp restores_volume(ctx, item, ordinal, step) do
    case count_item(ctx, item) do
      0 -> new_volume(ctx, item, ordinal)
      1 when step == 71 and item == 11_016 -> duplicate_fourth_volume(ctx)
      1 -> duplicate_volume(ctx, ordinal)
      _ -> mismatched_pages(ctx, step)
    end
  end

  defp thanks_for_restoration(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes("Thank you for your hard work. We were able to restore one volume of the report.")
    |> next()
  end

  defp new_volume(ctx, item, ordinal) do
    ctx
    |> thanks_for_restoration()
    |> delitem(6040, 10)
    |> give_item(item, 1)
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "This is the #{ordinal} volume of the report. I'm glad that we've restored atleast the #{ordinal} part."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes("Keep up the good work on finding the rest of the volumes.")
    |> close()
  end

  defp duplicate_volume(ctx, ordinal) do
    ctx
    |> thanks_for_restoration()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Unfortunately, this is the #{ordinal} volume of the report which we've restored already. I'm sorry, but we need to find pages for the rest of the volumes."
    )
    |> delitem(6040, 10)
    |> close()
  end

  defp duplicate_fourth_volume(ctx) do
    ctx
    |> delitem(6040, 10)
    |> thanks_for_restoration()
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "Unfortunately, this is the fourth volume of the report which we've restored already. I'm sorry, but we need to find pages for the rest of the volumes."
    )
    |> close()
  end

  defp mismatched_pages(ctx, 71) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> delitem(6040, 10)
    |> mes(
      "I'm sorry, but you've brought pages from different volumes of the report, I was unable to put them in order."
    )
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes("I'm sorry, but please go try to find pages that can be bound into one volume.")
    |> close()
  end

  defp mismatched_pages(ctx, 72) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "I'm sorry, but you've brought pages from different volumes of the report, I was unable to put them in order."
    )
    |> next()
    |> delitem(6040, 10)
    |> mes("[Staff Officer Abidal]")
    |> mes("I'm sorry, but please go try to find pages that can be bound into one volume.")
    |> close()
  end

  defp checks_restoration(ctx) do
    ctx =
      ctx
      |> mes("[Staff Officer Abidal]")
      |> mes("Let's see how far we've progressed on the report's restoration.")

    case {count_item(ctx, 11_013), count_item(ctx, 11_014), count_item(ctx, 11_015),
          count_item(ctx, 11_016)} do
      {1, 1, 1, 1} ->
        binds_the_report(ctx)

      {0, 0, 0, 0} ->
        reports_progress(
          ctx,
          "Well, you haven't restored any volumes of the report yet. Please try harder."
        )

      {1, 0, 0, 0} ->
        reports_progress(
          ctx,
          "You have restored the first volume of the report. There are 3 volumes left to restore."
        )

      {0, 1, 0, 0} ->
        reports_progress(
          ctx,
          "You have restored the second volume of the report. There are 3 volumes left to restore."
        )

      {0, 0, 1, 0} ->
        reports_progress(
          ctx,
          "You have restored the third volume of the report. There are 3 volumes left to restore."
        )

      {0, 0, 0, 1} ->
        reports_progress(
          ctx,
          "You have restored the fourth volume of the report. There are 3 volumes left to restore."
        )

      {1, 1, 0, 0} ->
        reports_progress(
          ctx,
          "You have restored the first and second volume of the report. There are 2 volumes left to restore."
        )

      {1, 0, 1, 0} ->
        reports_progress(
          ctx,
          "You have restored the first and third volume of the report. There are 2 volumes left to restore."
        )

      {1, 0, 0, 1} ->
        reports_progress(
          ctx,
          "You have restored the first and fourth volume of the report. There are 2 volumes left to restore."
        )

      {0, 1, 1, 0} ->
        reports_progress(
          ctx,
          "You have restored the second and third volume of the report. There are 2 volumes left to restore."
        )

      {0, 1, 0, 1} ->
        reports_progress(
          ctx,
          "You have restored the second and fourth volume of the report. There are 2 volumes left to restore."
        )

      {0, 0, 1, 1} ->
        reports_progress(
          ctx,
          "You have restored the third and fourth volume of the report. There are 2 volumes left to restore."
        )

      {1, 1, 1, 0} ->
        reports_progress(
          ctx,
          "You have restored the first, second and third volume of the report. There is 1 volume left to restore."
        )

      {0, 1, 1, 1} ->
        reports_progress(
          ctx,
          "You have restored the second, third and fourth volume of the report. There is 1 volume left to restore."
        )

      _ ->
        close(ctx)
    end
  end

  defp reports_progress(ctx, text) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes(text)
    |> close()
  end

  defp binds_the_report(ctx) do
    ctx =
      ctx
      |> next()
      |> mes("[Staff Officer Abidal]")
      |> mes(
        "Oh, great! Every volume of the report has been restored. I'll bind them into one book for you."
      )
      |> next()
      |> delitem(11_013, 1)
      |> delitem(11_014, 1)
      |> delitem(11_015, 1)
      |> delitem(11_016, 1)
      |> give_item(11_012, 1)
      |> set_char_var(:ep13_1_edq, 8)

    ctx = if isbegin_quest(ctx, 3090) > 0, do: erasequest(ctx, 3090), else: ctx
    ctx = if isbegin_quest(ctx, 3091) > 0, do: erasequest(ctx, 3091), else: ctx

    ctx
    |> setquest(3092)
    |> mes("[Staff Officer Abidal]")
    |> mes(
      "I'm glad that we were able to make this again. Please bring this report to the commander."
    )
    |> close()
  end

  defp resumes_the_mission(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes("Phew, I'm glad we can resume the mission again.")
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes("...Aren't you leaving? I think you should.")
    |> close()
  end

  defp mentions_the_new_duty(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes("I heard that you got a new duty from Commander Agip.")
    |> next()
    |> mes("[Staff Officer Abidal]")
    |> mes("...Aren't you leaving? I think you should.")
    |> close()
  end

  defp greets_the_adventurer(ctx) do
    ctx
    |> mes("[Staff Officer Abidal]")
    |> mes("Hello, I'm Staff Officer Abidal. Safe travels, Adventurer.")
    |> close()
  end
end
