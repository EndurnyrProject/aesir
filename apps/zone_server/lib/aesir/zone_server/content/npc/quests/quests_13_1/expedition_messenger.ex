defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.ExpeditionMessenger do
  @moduledoc """
  The expedition messenger who takes the commander's report, then has it destroyed by the
  shadowed figure that ambushes the hand-off.

  ## Behavior

  - At `ep13_1_edq` step 3 with the Expedition Report in hand runs the hand-off: the messengers
    leave, the shadowed figure appears and asks for the report.
  - Either answer plays the same ambush, then the report is destroyed: quest 3087 advances to
    3088 and the step becomes 4 (giving it) or 5 (protecting it).
  - At step 3 without the report it asks the player to bring it, at steps 4 and 5 it hurries them
    to the commander, and otherwise waits on duty.

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
        map: "mid_camp",
        x: 206,
        y: 286,
        dir: 3,
        sprite: 997,
        name: "Expedition Messenger",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @second_messenger "Expedition Messenger#2"
  @third_messenger "Expedition Messenger#3"
  @report 11012

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    # The conditions are re-read per clause, exactly as the reference evaluates them.
    cond do
      get_char_var(ctx, :ep13_1_edq, 0) == 3 and count_item(ctx, @report) > 0 ->
        hand_over(ctx)

      get_char_var(ctx, :ep13_1_edq, 0) == 3 and count_item(ctx, @report) == 0 ->
        missing_report(ctx)

      get_char_var(ctx, :ep13_1_edq, 0) > 3 and get_char_var(ctx, :ep13_1_edq, 0) < 6 ->
        hurry_to_the_commander(ctx)

      true ->
        waiting_duty(ctx)
    end
  end

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    ctx
    |> donpcevent("#{@second_messenger}::OnDisable")
    |> donpcevent("#{@third_messenger}::OnDisable")
    |> donpcevent("Command Timer#edq::OnEnable")
  end

  defp missing_report(ctx) do
    ctx
    |> mes("[Expedition Messenger]")
    |> mes("Were you assigned to deliver the expedition report?")
    |> next()
    |> mes("[Expedition Messenger]")
    |> mes(
      "I'm sorry, but I don't see any report in your hands. Please bring me the report, so I can confirm your identification."
    )
    |> close()
  end

  defp hurry_to_the_commander(ctx) do
    ctx
    |> mes("[Expedition Messenger]")
    |> mes("Please hurry up and report this incident to the commander.")
    |> close()
  end

  defp waiting_duty(ctx) do
    ctx
    |> mes("[Expedition Messenger]")
    |> mes("Good day! I'm here, just waiting for someone. Well, that's my duty.")
    |> close()
  end

  defp hand_over(ctx) do
    ctx =
      ctx
      |> mes("[Expedition Messenger]")
      |> mes("Welcome, I've been waiting for you.")

    ctx =
      ctx
      |> mes("You must be #{char_name(ctx, 0)}. Nice to meet you.")
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes(
        "Let me check something quicly. You received the report directly from the commander, didn't you? May I see it?"
      )
      |> next()
      |> mes("...")
      |> mes("......")
      |> mes(".........")
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes(
        "Excellent. Thank you. Then we'll go back to the mainland and let the leaders know that you, #{char_name(ctx, 0)}, have departed."
      )
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes("Guys, it's time to go.")
      |> next()
      |> donpcevent("#{@second_messenger}::Ongo")
      |> mes("[Expedition Messenger]")
      |> mes("You, head to Schwaltzval Republic.")
      |> mes("And you, take Arunafeltz. I'll visit Prontera Palace.")

    {ctx, choice} =
      ctx
      |> emotion(:ok, getnpcid(ctx, @second_messenger))
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes("I'll see you guys later.")
      |> donpcevent("#{@second_messenger}::OnDisable")
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes("What's up? Why haven't you left...?")
      |> specialeffect(:soulbreaker, :area, "Expedition Messenger")
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes("Argh... Why are you doing this?!")
      |> next()
      |> cutin("ep13_shadow_edq", 2)
      |> mes("[???]")
      |> mes("......")
      |> next()
      |> mes("[???]")
      |> mes("Give me the report.")
      |> next()
      |> select(["Give the report.", "Protect the report."])

    case choice do
      1 -> gives_the_report(ctx)
      2 -> protects_the_report(ctx)
      _ -> ctx
    end
  end

  defp gives_the_report(ctx) do
    ctx =
      ctx
      |> mes("[Expedition Messenger]")
      |> mes("Wha... What are you doing? You can't give up the report...")
      |> mes("Awww...")
      |> next()
      |> mes("[???]")
      |> mes("Give it to me, now!")
      |> next()
      |> donpcevent("#{@second_messenger}::OnEnable")

    ctx =
      ctx
      |> emotion(:surprise, getnpcid(ctx, @third_messenger))
      |> cutin("ep13_shadow_edq", 2)
      |> mes("[???]")
      |> mes("Argh...")
      |> next()
      |> specialeffect(:soulbreaker, :area, @third_messenger)
      |> specialeffect(:soulbreaker, :area, @third_messenger)
      |> mes("[???]")
      |> mes("Argh... You...")
      |> next()
      |> mes("[Expedition Messenger]")

    ctx =
      ctx

    ctx =
      ctx
      |> mes("*Cough* Oh, thank god! #{char_name(ctx, 0)}, please take the report and run!")
      |> next()
      |> mes("[???]")
      |> mes("No... Noooo!")
      |> next()
      |> specialeffect2(:soulbreaker)
      |> specialeffect2(:sonicblowhit)
      |> mes("[Expedition Messenger]")

    ctx =
      ctx

    ctx =
      ctx
      |> mes("Argh... #{char_name(ctx, 0)}, are you alright? The report... The report...")
      |> next()
      |> delitem(@report, 1)
      |> set_char_var(:ep13_1_edq, 4)
      |> changequest(3087, 3088)
      |> mes("[Expedition Agent]")
      |> mes("We lost the report. The pages are blowing away!")
      |> next()
      |> mes("[???]")
      |> mes(
        "Haha, I may have failed to take the report, but it's better destroyed than in your hands!"
      )
      |> cutin("ep13_shadow_edq", 255)
      |> next()
      |> donpcevent("#{@third_messenger}::OnDisable")

    ctx =
      ctx
      |> mes("[Expedition Agent]")
      |> mes("Are you alright? What about the report... ?")
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes("*Cough* The report is out of our reach now...")
      |> next()
      |> mes("[Expedition Agent]")
      |> mes("If we mobilize all our troops to search this entire area...")
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes("We must report this to the commander before anything else.")

    ctx
    |> mes(
      "#{char_name(ctx, 0)}, please report to the commander immidiatly. Let us take care of the rest."
    )
    |> donpcevent("#{@second_messenger}::OnDisable")
    |> next()
    |> mes("[Expedition Agent]")
    |> mes("Yes, please report to the commander...")
    |> close()
  end

  defp protects_the_report(ctx) do
    ctx =
      ctx
      |> mes("[???]")
      |> mes("Oh, yeah? Then I'll have to use force!")
      |> next()
      |> donpcevent("#{@second_messenger}::OnEnable")

    ctx =
      ctx
      |> emotion(:surprise, getnpcid(ctx, @third_messenger))
      |> mes("[???]")
      |> mes("Argh!")
      |> next()
      |> specialeffect(:soulbreaker, :area, @third_messenger)
      |> specialeffect(:soulbreaker, :area, @third_messenger)
      |> mes("[???]")
      |> mes("Argh... You...")
      |> next()
      |> mes("[Expedition Messenger]")

    ctx =
      ctx

    ctx =
      ctx
      |> mes("*Cough* Oh, thank god! #{char_name(ctx, 0)}, please take the report and run!")
      |> next()
      |> mes("[???]")
      |> mes("No... Noooo!")
      |> next()
      |> specialeffect2(:soulbreaker)
      |> specialeffect2(:sonicblowhit)
      |> mes("[Expedition Messenger]")

    ctx =
      ctx

    ctx =
      ctx
      |> mes("Argh... #{char_name(ctx, 0)}, are you alright? The report... The report...")
      |> next()
      |> mes("[Expedition Agent]")
      |> mes("We lost the report. The pages are blowing away!")
      |> next()
      |> delitem(@report, 1)
      |> set_char_var(:ep13_1_edq, 5)
      |> changequest(3087, 3088)
      |> mes("[???]")
      |> mes(
        "Haha, I may have failed to take the report, but it's better destroyed than in your hands!"
      )
      |> cutin("ep13_shadow_edq", 255)
      |> next()
      |> donpcevent("#{@third_messenger}::OnDisable")

    ctx =
      ctx
      |> mes("[Expedition Agent]")
      |> mes("Are you alright? What about the report... ?")
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes("*Cough* The report is out of our reach now...")
      |> next()
      |> mes("[Expedition Agent]")
      |> mes("If we mobilize all our troops to search this entire area...")
      |> next()
      |> mes("[Expedition Messenger]")
      |> mes("We must report this to the commander before anything else.")

    ctx
    |> mes(
      "#{char_name(ctx, 0)}, please report to the commander immidiatly. Let us take care of the rest."
    )
    |> set_char_var(:ep13_1_edq, 5)
    |> next()
    |> mes("[Expedition Agent]")
    |> mes("Yes, please report to the commander...")
    |> close()
  end
end
