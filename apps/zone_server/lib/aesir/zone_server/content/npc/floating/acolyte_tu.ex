defmodule Aesir.ZoneServer.Content.Npc.Floating.AcolyteTu do
  @moduledoc """
  Mafra, the Acolyte trainee who helps the player train during the Archer quest.

  ## Behavior

  - At quest step 14, between 18:00 and 22:00, offers to train together. Accepting, or
    claiming that Reidin Corse belongs to the player, advances the quest step to 15;
    refusing closes without changing it.
  - Outside those hours she is asleep and only casts her spells before closing.
  - At step 15 she casts the support spells on every visit.
  - For any other quest step she only wonders why travelling makes her sleepy.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Jukka (fix up)
    - Lupus
    - L0ne_W0lf
    - SinSloth
    - Capuche
    - Euphy
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @first_visit_heal_levels [3, 9, 8]
  @repeat_visit_heal_levels [3, 10, 8]
  @incagi_levels [1, 5, 10]
  @blessing_levels [1, 5, 10]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx = mes(ctx, "[Acolyte]")

    case get_char_var(ctx, :tu_archer01, 0) do
      14 -> first_visit(ctx)
      15 -> repeat_visit(ctx)
      _ -> sleep_farewell(ctx)
    end
  end

  defp first_visit(ctx) do
    if awake?(ctx) do
      {ctx, choice} =
        ctx
        |> mes("H-hello!")
        |> mes("Umm, umm...")
        |> mes("Are you R-Reidin Corse's")
        |> mes("friend t-too?")
        |> next()
        |> mes("[Acolyte]")
        |> mes("M-my name is Mafra.")
        |> mes(
          "Ever since he saved my life, Reidin has a-always been a good f-friend to me. He's such a great Archer"
        )
        |> mes("and a really nice person!")
        |> next()
        |> mes("[Acolyte]")
        |> mes("Um, and...")
        |> mes("Uh... Oh no~")
        |> mes("What am I supposed")
        |> mes("t-to tell you...?")
        |> emotion(:profusely_sweat)
        |> next()
        |> mes("[Acolyte]")
        |> mes(
          "Oh, since I'm training to be an Acolyte, I'm supposed to help out the people he's teaching. So..."
        )
        |> mes("Let's h-help each other train!")
        |> mes("Um, is that okay?")
        |> next()
        |> select(["Sure.", "No thanks.", "Reidin Corse is mine!"])

      case choice do
        1 -> accept_training(ctx)
        2 -> decline_training(ctx)
        3 -> jealous_reply(ctx)
        _ -> sleep_farewell(ctx)
      end
    else
      ctx
      |> mes("^666666Zzzzz...^000000")
      |> mes("Wh-wha...?")
      |> mes("Who are you?")
      |> specialeffect(:sleepattack)
      |> next()
      |> mes("[Acolyte]")
      |> mes("Wait, I know...")
      |> mes("Y-you're... ^666666*Yawn*^000000")
      |> mes("So sleepy. Take this for now...")
      |> cast_support_spells(@first_visit_heal_levels)
      |> close()
    end
  end

  defp accept_training(ctx) do
    ctx
    |> mes("[Acolyte]")
    |> mes("Wow!")
    |> mes("Thank you, thank you!")
    |> mes("I''ll try my very best!")
    |> set_char_var(:tu_archer01, 15)
    |> close()
  end

  defp decline_training(ctx) do
    ctx
    |> mes("[Acolyte]")
    |> mes("Oh... Oh.")
    |> mes("I'm so sorry.")
    |> mes("If you don't need")
    |> mes("my help, I guess")
    |> mes("that's alright...")
    |> emotion(:cry)
    |> close()
  end

  defp jealous_reply(ctx) do
    ctx =
      ctx
      |> mes("[Acolyte]")
      |> mes("Eh?!")
      |> mes("R-really?")
      |> mes("I guess he doesn't")
      |> mes("need to tell me if")
      |> mes("he already has a girlfriend...")
      |> next()
      |> mes("[Acolyte]")

    ctx =
      if sex(ctx) == get_char_var(ctx, :SEX_MALE, 0) do
        ctx
        |> mes("W-wait!")
        |> mes("Y-you're a man!")
        |> mes("D-d-d-don't tease me")
        |> mes("like that! I'm serious!")
      else
        ctx
        |> mes("And he's so brave")
        |> mes("and funny and smart.")
        |> mes("Y-you're lucky to have him.")
        |> mes("^333333*Sniff*^000000 I... I...")
        |> next()
        |> mes("[Acolyte]")
        |> mes("^333333*Sniffle*^000000")
        |> mes("I'll d-do my best to help you!")
        |> mes("I wish you both happiness! (Waaaaaah~!)")
      end

    ctx
    |> set_char_var(:tu_archer01, 15)
    |> close()
  end

  defp repeat_visit(ctx) do
    ctx =
      if awake?(ctx) do
        ctx
        |> mes("^666666Zzzzz...^000000")
        |> mes("Wh-wha...?")
        |> mes("Who are you?")
        |> specialeffect(:sleepattack)
        |> next()
        |> mes("[Acolyte]")
        |> mes("Reidin Corse?")
        |> mes("I can't believe")
        |> mes("I feel asleep fo--")
        |> mes("^666666Zzzzzzz...^000000")
        |> next()
        |> mes("[Acolyte]")
        |> mes("^666666Zzzz^000000--Oooh!")
        |> mes("J-just take this before")
        |> mes("I fall asleep again~! ^666666*Yawn*^000000")
      else
        ctx
        |> mes("Okay~!")
        |> mes("Let me try")
        |> mes("casting a spell")
        |> mes("to help you! Yaa~p!")
      end

    ctx
    |> cast_support_spells(@repeat_visit_heal_levels)
    |> close()
  end

  defp sleep_farewell(ctx) do
    ctx
    |> mes("...")
    |> mes("W-why does")
    |> mes("traveling make")
    |> mes("me sooo sleepy...?")
    |> mes("^666666Zzzzzzzz...^000000")
    |> specialeffect(:sleepattack)
    |> close()
  end

  defp awake?(ctx), do: gettime(ctx, 3) >= 18 and gettime(ctx, 3) < 22

  defp cast_support_spells(ctx, heal_levels) do
    heal_level = Enum.at(heal_levels, :rand.uniform(4) - 1)
    incagi_level = Enum.at(@incagi_levels, :rand.uniform(3) - 1)
    blessing_level = Enum.at(@blessing_levels, :rand.uniform(3) - 1)

    ctx = if heal_level, do: npcskill(ctx, 28, heal_level, 90, 62), else: ctx

    ctx
    |> npcskill(29, incagi_level, 0, 0)
    |> npcskill(34, blessing_level, 0, 0)
  end
end
