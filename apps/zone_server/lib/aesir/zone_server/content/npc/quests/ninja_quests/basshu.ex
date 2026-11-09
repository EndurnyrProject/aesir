defmodule Aesir.ZoneServer.Content.Npc.Quests.NinjaQuests.Basshu do
  @moduledoc """
  Murata Basshu, antiques dealer of shields, improves an Arm Guard into a Slotted Arm Guard.

  ## Behavior

  - Turns non-Ninjas and characters below base level 50 away.
  - Asks for a Mirror Shield, the shield from overseas he wants to study, and
    tracks the errand in `ninbot` (1: looking for the shield, 2: bring the
    materials).
  - Once the Mirror Shield has been seen, trades 1 Mirror Shield, 1 Arm Guard
    and 20,000 Zeny for a Slotted Arm Guard, re-offering the trade on later
    visits while `MISC_QUEST` bit 4096 is set.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Playtester
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/ninja_quests.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [%{map: "que_ng", x: 28, y: 45, dir: 3, sprite: 86, name: "Basshu", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @mirror_shield 2107
  @arm_guard 2117
  @slotted_arm_guard 2119
  @fee 20_000
  @guard_bit 4096

  @only_once "Come again when you have these materials."

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_class(ctx)) != Rathena.job_id(:ninja) -> turn_away(ctx)
      base_level(ctx) < 50 -> too_weak(ctx)
      count_item(ctx, @mirror_shield) < 1 and not guard_unlocked?(ctx) -> introduce(ctx)
      true -> resume(ctx)
    end
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Basshu]")
    |> mes(
      "I am one of the brothers of the three brothers in charge of crafting shields in the east named Murata Basshu"
    )
    |> next()
    |> mes("[Basshu]")
    |> mes(
      "People normally call us the Three Craftsmen, but the other two craftsmen are my brothers."
    )
    |> next()
    |> mes("[Basshu]")
    |> mes(
      "But It looks like you're not my usual customer type, so I cannot make you any shields."
    )
    |> mes("Sorry.")
    |> close()
  end

  defp too_weak(ctx) do
    ctx
    |> mes("[Basshu]")
    |> mes(
      "I am one of the brothers of the three brothers in charge of crafting shields in the east named Murata Basshu"
    )
    |> next()
    |> mes("[Basshu]")
    |> mes(
      "Unfortunately, many of my shields have minimum requirements, and I'm afraid you would not meet them."
    )
    |> next()
    |> mes("[Basshu]")
    |> mes("Come back when you're stronger.")
    |> close()
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Basshu]")
      |> mes(
        "I am one of the brothers of the three craftsmen in charge of crafting shields in the east named Murata Basshu"
      )
      |> next()
      |> mes("[Basshu]")
      |> mes("We are called the Three Craftsmen, but the other two craftsmen are my brothers.")
      |> mes(
        "I've learned my craft by sneaking looks over my brothers, so my skill is a little less than them, but many people praise me highly."
      )
      |> next()
      |> mes("[Basshu]")
      |> mes(
        "As of now, I've given up making shields and am currently running an antique shop for shields."
      )
      |> mes("I'm researching to see if shields can be enchanted with magic.")
      |> next()
      |> mes("[Basshu]")
      |> mes("Do you happen to know a shield called the Mirror shield from overseas?")
      |> mes("I'd love to see that item, but I can't get my hands on one.")
      |> next()
      |> mes("[Basshu]")
      |> mes("It'd help me greatly if I could see that shield up close.")
      |> mes("Can you help me?")
      |> next()
      |> select(["Hmm...I don't feel like it.", "Very well."])

    if choice == 1, do: refuse_errand(ctx), else: accept_errand(ctx)
  end

  defp refuse_errand(ctx) do
    ctx
    |> mes("[Basshu]")
    |> mes("Ah~ I guess it was an impossible request.")
    |> mes("I'm sorry.")
    |> mes("If you ever find a Mirror shield and want to get rid of it, please come and see me.")
    |> close()
  end

  defp accept_errand(ctx) do
    ctx
    |> mes("[Basshu]")
    |> mes("Oh, thank you.")
    |> mes("If you could really find me a Mirror Shield, I might get some really good ideas.")
    |> set_char_var(:ninbot, 1)
    |> close()
  end

  defp resume(ctx) do
    case get_char_var(ctx, :ninbot, 0) do
      1 -> examine_shield(ctx)
      2 -> hand_over(ctx)
      _ -> if guard_unlocked?(ctx), do: repeat_order(ctx), else: first_order(ctx)
    end
  end

  defp examine_shield(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Basshu]")
      |> mes("Oh. You have it?")
      |> mes("Let me see...")
      |> mes("Hmm ...")
      |> next()
      |> mes("[Basshu]")
      |> mes(
        "Oh! That's it! This proves it's not impossible to make a shield resistant to magical attacks."
      )
      |> mes("Whew...")
      |> next()
      |> mes("[Basshu]")
      |> mes("This sure gets me excited.")
      |> mes("If you have a normal Arm Guard, bring me your Arm Guard, and...")
      |> next()
      |> mes("[Basshu]")
      |> mes("1 Mirror Shield, and")
      |> mes("20,000 Zeny, and I'll improve your Arm Guard into an Improved Arm Guard.")
      |> next()
      |> mes("[Basshu]")
      |> mes("How about it? Would you like that?")
      |> next()
      |> select(["No, I wouldn't.", "Yes, I would."])

    if choice == 1, do: drop_errand(ctx), else: take_order(ctx)
  end

  defp drop_errand(ctx) do
    ctx
    |> mes("[Basshu]")
    |> mes("Hmm, Very Well.")
    |> mes("I'm so grateful you showed me that rare shield from overseas.")
    |> next()
    |> mes("[Basshu]")
    |> mes("Thanks for everything.")
    |> set_char_var(:ninbot, 0)
    |> close()
  end

  defp take_order(ctx) do
    ctx
    |> mes("[Basshu]")
    |> mes("Very Well.")
    |> mes("I'm looking forward to this.")
    |> next()
    |> mes("[Basshu]")
    |> mes("Bring me 1 Arm Guard,")
    |> mes("1 Mirror Shield, and")
    |> mes("20,000 Zeny,")
    |> mes("and I'll make you an Improved Arm Guard.")
    |> next()
    |> mes("[Basshu]")
    |> mes("Come and see me when you have everything ready.")
    |> set_char_var(:ninbot, 2)
    |> close()
  end

  defp hand_over(ctx) do
    cond do
      not materials_ready?(ctx) ->
        missing_materials(
          ctx,
          [
            "Hmm.. It looks like there aren't enough materials.",
            "For an Improved Arm Guard, I require...",
            "1 Mirror Shield, 1 Arm Guard",
            "and 20,000 Zeny."
          ]
        )

      zeny(ctx) < @fee ->
        missing_materials(
          ctx,
          [
            "Hmm.. You brought plenty of materials, but you're short on zeny.",
            "In order to create an Improved Arm Guard, I require...",
            "1 Mirror Shield, 1 Arm Guard",
            "and 20,000 Zeny."
          ]
        )

      true ->
        {ctx, choice} =
          ctx
          |> mes("[Basshu]")
          |> mes("The proper ingredients")
          |> mes("have been gathered.")
          |> mes("Before I begin,")
          |> mes("I'll ask one last time.")
          |> next()
          |> mes("[Basshu]")
          |> mes(
            "In trade of the magical defence of the Arm Guard increasing, the shield's ability to block physical attacks may inevitably decrease."
          )
          |> next()
          |> mes("[Basshu]")
          |> mes("Will you give me the materials you've gathered")
          |> mes("and in trade, receive an Improved Arm Guard?")
          |> next()
          |> select(["No", "Yes"])

        if choice == 1,
          do: keep_materials(ctx, ["If you ever make up your mind"]),
          else: forge(ctx)
    end
  end

  defp forge(ctx) do
    ctx =
      ctx
      |> mes("[Basshu]")
      |> mes("Hmm~ Well then~")
      |> mes("Shall we begin?")
      |> mes("Bang Clang ~Bang Clang ~")
      |> mes("Sweep Sweep~ Saw Saw~")
      |> next()

    if not materials_ready?(ctx) or zeny(ctx) < @fee do
      ctx |> mes("HACK DETECTED") |> close()
    else
      ctx
      |> mes("[Basshu]")
      |> mes("Here it is -- it's complete.")
      |> mes("I've made you an Improved Arm Guard.")
      |> mes("If you ever want me to create more items, come and ask me anytime.")
      |> charge()
      |> set_char_var(:ninbot, 0)
      |> unlock_guard()
      |> give_item(@slotted_arm_guard, 1)
      |> close()
    end
  end

  # A player who already owns the Shield from overseas but never met the quest
  # yet gets the full first-time hand-in.
  defp first_order(ctx) do
    {ctx, choice} =
      ctx
      |> set_char_var(:ninbot, 0)
      |> mes("[Basshu]")
      |> mes("Why~ That's~!")
      |> mes("Is what you have there that shield which is called a 'Mirror Shield' overseas?")
      |> next()
      |> mes("[Basshu]")
      |> mes("Excuse me, but may I take a look?")
      |> next()
      |> mes("[Basshu]")
      |> mes("I knew it!! It is a Mirror Shield~!")
      |> mes("There must be a way any shield can posess magical powers!!")
      |> next()
      |> mes("[Basshu]")
      |> mes("Shields could be much more useful than now.")
      |> mes("Why didn't I think of this before?")
      |> next()
      |> mes("[Basshu]")
      |> mes("I have two brothers, and together we are the Three Craftsmen of the East.")
      |> mes("I learned my crafting skill by watching my older brothers.")
      |> next()
      |> mes("[Basshu]")
      |> mes(
        "Due to that, my skill is not as good as theirs, but many people say I am skilled..."
      )
      |> next()
      |> mes("[Basshu]")
      |> mes(
        "As of now, I have also given up making shields and am currently running an antique shop for shields."
      )
      |> next()
      |> mes("[Basshu]")
      |> mes("I'm researching to see if shields can be enchanted with magic.")
      |> next()
      |> mes("[Basshu]")
      |> mes(
        "Therefore, I wanted to get an idea of how magic works on shields by studying a shield from overseas called the Mirror Shield, but I couldn't get my hands on one."
      )
      |> mes("What stress that had caused me.")
      |> next()
      |> mes("[Basshu]")
      |> mes(
        "But luckily, you, a traveller, happened to have a mirror shield, and now I feel my creative spirit burning lively inside."
      )
      |> next()
      |> mes("[Basshu]")
      |> mes(
        "If you want, I will make you an Improved Arm Guard if you bring me 1 Arm Guard, 1 Mirror Shield, And 20,000 Zeny."
      )
      |> mes("Would you like to try using one?")
      |> next()
      |> select(["No, I don't wanna!", "Yeah~!! Hurry and make it for me!"])

    if choice == 1, do: brush_off(ctx), else: first_order_checks(ctx)
  end

  defp brush_off(ctx) do
    ctx
    |> mes("[Basshu]")
    |> mes("Hmm, is that so.")
    |> mes("What a shame.")
    |> mes("Come and find me if you change your mind.")
    |> close()
  end

  defp first_order_checks(ctx) do
    cond do
      not materials_ready?(ctx) ->
        missing_materials(
          ctx,
          [
            "Hmm.. It looks like there aren't enough materials.",
            "In order to create an Improved Arm Guard, I require...",
            "1 Mirror Shield, 1 Arm Guard",
            "And 20,000 Zeny"
          ]
        )

      zeny(ctx) < @fee ->
        missing_materials(
          ctx,
          [
            "Hmm.. You brought plenty of materials, but you're short on zeny.",
            "In order to make an Improved Arm Guard, I require...",
            "1 Mirror Shield, 1 Arm Guard,",
            "And 20,000 Zeny."
          ]
        )

      true ->
        {ctx, choice} =
          ctx
          |> mes("[Basshu]")
          |> mes("The proper ingredients")
          |> mes("have been gathered.")
          |> mes("Before I begin,")
          |> mes("I'll ask one last time.")
          |> next()
          |> mes("[Basshu]")
          |> mes(
            "In trade of the magical defence of the Arm Guard increasing, the shield's ability to block physical attacks may inevitably decrease."
          )
          |> next()
          |> mes("[Basshu]")
          |> mes("Will you give me the materials you've gathered")
          |> mes("to receive an Improved Arm Guard?")
          |> next()
          |> select(["No", "Yes"])

        if choice == 1,
          do: keep_materials(ctx, ["If you ever make up your mind"]),
          else: first_forge(ctx)
    end
  end

  defp first_forge(ctx) do
    ctx =
      ctx
      |> mes("[Basshu]")
      |> mes("Hmm~ Well then~")
      |> mes("Shall we begin?")
      |> mes("Bang Clang ~Bang Clang ~")
      |> mes("Sweep Sweep~ Saw Saw~")
      |> next()

    if not materials_ready?(ctx) or zeny(ctx) < @fee do
      ctx |> mes("HACK DETECTED") |> close()
    else
      ctx
      |> mes("[Basshu]")
      |> mes("Here it is -- it's complete.")
      |> mes("I've made you an Improved Arm Guard")
      |> mes("If you ever want me to create more items, come and ask me anytime.")
      |> charge()
      |> unlock_guard()
      |> give_item(@slotted_arm_guard, 1)
      |> close()
    end
  end

  defp repeat_order(ctx) do
    {ctx, choice} =
      ctx
      |> set_char_var(:ninbot, 0)
      |> mes("[Basshu]")
      |> mes("Oh~ I see you've come back.")
      |> mes("Are you here because you need an Improved Arm Guard?")
      |> next()
      |> select(["Nope, not really.", "Yes, make me another one."])

    if choice == 1, do: not_really(ctx), else: repeat_checks(ctx)
  end

  defp not_really(ctx) do
    ctx
    |> mes("[Basshu]")
    |> mes("Aha~ I see~.")
    |> mes("Come back and talk to me anytime.")
    |> close()
  end

  defp repeat_checks(ctx) do
    cond do
      not materials_ready?(ctx) ->
        missing_materials(
          ctx,
          [
            "Hmm.. It looks like there aren't enough materials.",
            "In order to make an Improved Arm Guard, I require...",
            "1 Mirror Shield, 1 Arm Guard,",
            "And 20,000 Zeny."
          ]
        )

      zeny(ctx) < @fee ->
        missing_materials(
          ctx,
          [
            "Hmm.. You brought plenty of materials, but you're short on zeny.",
            "In order to make an Improved Arm Guard, I require...",
            "1 Mirror Shield, 1 Arm Guard,",
            "and 20,000 Zeny."
          ]
        )

      true ->
        {ctx, choice} =
          ctx
          |> mes("[Basshu]")
          |> mes("Looks like you brought me the correct ingredients.")
          |> mes("Before I begin,")
          |> mes("I'll ask one last time.")
          |> next()
          |> mes("[Basshu]")
          |> mes(
            "In trade of the magical defence of the Arm Guard increasing, the shield's ability to block physical attacks may inevitably decrease."
          )
          |> next()
          |> mes("[Basshu]")
          |> mes(
            "Will you give me the materials you've gathered to receive an Improved Arm Guard?"
          )
          |> next()
          |> select(["No", "Yes"])

        if choice == 1,
          do: keep_materials(ctx, ["If you make up your mind"]),
          else: repeat_forge(ctx)
    end
  end

  defp repeat_forge(ctx) do
    ctx =
      ctx
      |> mes("[Basshu]")
      |> mes("Hmm~ Well then~")
      |> mes("Shall we begin?")
      |> mes("Bang Clang ~Bang Clang ~")
      |> mes("Sweep Sweep~ Saw Saw~")
      |> next()
      |> mes("[Basshu]")
      |> mes("Here it is -- it's complete.")
      |> mes("I've made you an Improved Arm Guard")
      |> next()

    if not materials_ready?(ctx) or zeny(ctx) < @fee do
      ctx |> mes("HACK DETECTED") |> close()
    else
      ctx
      |> mes("[Basshu]")
      |> mes("If you ever want me to create more items, come and ask me anytime.")
      |> charge()
      |> give_item(@slotted_arm_guard, 1)
      |> close()
    end
  end

  defp missing_materials(ctx, lines) do
    ctx
    |> mes("[Basshu]")
    |> say(lines)
    |> mes(@only_once)
    |> close()
  end

  defp keep_materials(ctx, lines) do
    ctx
    |> mes("[Basshu]")
    |> mes("Very Well.")
    |> say(lines)
    |> mes("come and find me again.")
    |> close()
  end

  defp materials_ready?(ctx) do
    count_item(ctx, @mirror_shield) >= 1 and count_item(ctx, @arm_guard) >= 1
  end

  # The trade consumes the Mirror Shield before the Arm Guard, then the fee.
  defp charge(ctx) do
    ctx
    |> delitem(@mirror_shield, 1)
    |> delitem(@arm_guard, 1)
    |> pay_zeny(@fee)
  end

  defp guard_unlocked?(ctx), do: unlocked?(get_char_var(ctx, :MISC_QUEST, 0))

  defp unlock_guard(ctx) do
    set_char_var(ctx, :MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), @guard_bit))
  end

  defp unlocked?(quest_bits), do: Rathena.truthy?(:erlang.band(quest_bits, @guard_bit))

  defp say(ctx, lines), do: Enum.reduce(lines, ctx, fn line, ctx -> mes(ctx, line) end)
end
