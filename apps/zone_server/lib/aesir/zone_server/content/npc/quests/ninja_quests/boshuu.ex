defmodule Aesir.ZoneServer.Content.Npc.Quests.NinjaQuests.Boshuu do
  @moduledoc """
  Murata Boshuu, the best of the three eastern craftsmen, slots an Arm Guard into a Slotted Arm Guard.

  ## Behavior

  - Turns non-Ninjas and characters below base level 20 away.
  - Asks for the slotted Guard from overseas so he can study it, and tracks the
    errand in `ninbo` (1: looking for the Guard, 2: bring the materials).
  - Once the Guard has been seen, trades 1 Slotted Guard, 1 Arm Guard and 10,000
    Zeny for a Slotted Arm Guard, re-offering the trade on later visits while
    `MISC_QUEST` bit 2048 is set.

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
    spawn: [%{map: "que_ng", x: 28, y: 50, dir: 3, sprite: 709, name: "Boshuu", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @slotted_guard 2102
  @arm_guard 2117
  @slotted_arm_guard 2118
  @fee 10_000
  @guard_bit 2048

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    cond do
      Rathena.job_id(base_class(ctx)) != Rathena.job_id(:ninja) -> turn_away(ctx)
      base_level(ctx) < 20 -> too_weak(ctx)
      count_item(ctx, @slotted_guard) < 1 and not guard_unlocked?(ctx) -> introduce(ctx)
      true -> resume(ctx)
    end
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Boshuu]")
    |> mes("I'm the best craftsman out of what people call the Three Craftsmen of Ninja Tools.")
    |> mes("They call me Murata Boshuu.")
    |> next()
    |> mes("[Boshuu]")
    |> mes(
      "I know how to create any armor and shield of the eastern world, and my shields are considered the best there is."
    )
    |> next()
    |> mes("[Boshuu]")
    |> mes("But seeing how you are an outsider...")
    |> mes("Looks like I have no business with you.")
    |> mes("Ehem~")
    |> close()
  end

  defp too_weak(ctx) do
    ctx
    |> mes("[Boshuu]")
    |> mes("I make the best shields for Ninjas of all ages,")
    |> mes("But even I have some minimum requirements")
    |> next()
    |> mes("[Boshuu]")
    |> mes("It looks like what you need isn't a shield, but more levels.")
    |> mes("Come back after you've grown a bit more.")
    |> close()
  end

  defp introduce(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Boshuu]")
      |> mes("I'm the best craftsman out of what people call the Three Craftsmen of Ninja Tools.")
      |> mes("They call me Murata Boshuu.")
      |> next()
      |> mes("[Boshuu]")
      |> mes("They say it's three craftsmen, but the other two are probably scammers.")
      |> mes("There's not a single craftsman better than I for ninjas in this world.")
      |> next()
      |> mes("[Boshuu]")
      |> mes("I know how to make all the eastern armor and shield.")
      |> next()
      |> mes("[Boshuu]")
      |> mes(
        "Because the armor I'd create was so superior and defensive, when two people battle wearing armor made by me, no one can win!"
      )
      |> next()
      |> mes("[Boshuu]")
      |> mes("For that reason, I no longer make any armor.")
      |> mes(
        "I'm only collecting armors nowadays, just to make sure my skills do not go to waste.."
      )
      |> next()
      |> mes("[Boshuu]")
      |> mes("But I feel so bored nowadays.")
      |> next()
      |> mes("[Boshuu]")
      |> mes(
        "Now that I only collect armor, I feel like the creative flame within me is dying out."
      )
      |> next()
      |> mes("[Boshuu]")
      |> mes("From what I heard, there's an armor overseas which I haven't even heard of.")
      |> mes("It was called a... hmm.. what was it called?")
      |> next()
      |> mes("[Boshuu]")
      |> mes("^ff0000Guard[1]^000000? Well, it's a name like that.")
      |> mes("I wish to see the real thing myself.")
      |> next()
      |> mes("[Boshuu]")
      |> mes("But obviously, it's probably worthless compared to the armor I make.")
      |> next()
      |> mes("[Boshuu]")
      |> mes("Do me a favor and I'll make you something special.")
      |> next()
      |> mes("[Boshuu]")
      |> mes(
        "I'm not sure what I'll do, but I get the feeling I'll feel inspired once I see that armor."
      )
      |> mes("How 'bout it~ Will you find me a ^ff0000Guard[1]^000000?")
      |> next()
      |> select(["Hmm.. I don't feel like it.", "Very well."])

    if choice == 1, do: refuse_errand(ctx), else: accept_errand(ctx)
  end

  defp refuse_errand(ctx) do
    ctx
    |> mes("[Boshuu]")
    |> mes("Ah~ What a shame..")
    |> mes(
      "You're missing out on an opportunity to get your hands on something made by a genius craftsman like myself..."
    )
    |> close()
  end

  defp accept_errand(ctx) do
    ctx
    |> mes("[Boshuu]")
    |> mes("Oh, Very well.")
    |> mes("Get a move on.")
    |> mes("Find the shield called ^ff0000Guard[1]^000000 and bring it to me.")
    |> set_char_var(:ninbo, 1)
    |> close()
  end

  defp resume(ctx) do
    case get_char_var(ctx, :ninbo, 0) do
      1 -> examine_guard(ctx)
      2 -> hand_over(ctx)
      _ -> if guard_unlocked?(ctx), do: repeat_order(ctx), else: first_order(ctx)
    end
  end

  defp examine_guard(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Boshuu]")
      |> mes("Oh.. so did you bring it?")
      |> mes("Show it to me...")
      |> mes("Hmmmmm...")
      |> next()
      |> mes("[Boshuu]")
      |> mes("Oh~ ! I see, it's even possible to slot armor!")
      |> next()
      |> mes("[Boshuu]")
      |> mes(
        "Ahh, Now I'm just itching to imitating this armor and making a slot on other armors."
      )
      |> next()
      |> mes("[Boshuu]")
      |> mes(
        "If you have a regular non-slotted Arm Guard and a slotted Guard, I'll make the non-slotted one slotted at the cost of 10,000 Zeny."
      )
      |> next()
      |> mes("[Boshuu]")
      |> mes("How 'bout it? Want to try?")
      |> next()
      |> select(["No thanks.", "Ok, sounds good."])

    if choice == 1, do: drop_errand(ctx), else: take_order(ctx)
  end

  defp drop_errand(ctx) do
    ctx
    |> mes("[Boshuu]")
    |> mes("Hmm, Ok.")
    |> mes("I'm so grateful that I was able to see such a rare thing from overseas.")
    |> mes("Thanks for everything.")
    |> set_char_var(:ninbo, 0)
    |> close()
  end

  defp take_order(ctx) do
    ctx
    |> mes("[Boshuu]")
    |> mes("Oh ok.")
    |> mes("I can't wait to begin.")
    |> mes("If you bring me 1 Arm Guard")
    |> mes("1 Slotted Guard, and")
    |> mes("10,000 Zeny..")
    |> next()
    |> mes("[Boshuu]")
    |> mes("Then I'll slot your slotless Arm Guard.")
    |> mes("Come back when you have all the required materials.")
    |> set_char_var(:ninbo, 2)
    |> close()
  end

  defp hand_over(ctx) do
    cond do
      not materials_ready?(ctx) ->
        ctx
        |> mes("[Boshuu]")
        |> mes("Hmm... It looks like you didn't bring me enough materials.")
        |> mes("In order to create a Slotted Arm Guard, I need 1 Slotted Guard")
        |> mes("1 Arm Guard, and 10,000 Zeny")
        |> mes("Come back when you're sure you have everything.")
        |> close()

      zeny(ctx) < @fee ->
        ctx
        |> mes("[Boshuu]")
        |> mes("Hmm.. You brought plenty of materials, but you're short on zeny.")
        |> next()
        |> mes("[Boshuu]")
        |> mes("In order to create a Slotted Arm Guard, I need 1 Guard[1]")
        |> mes("1 Arm Guard, and 10,000 Zeny.")
        |> mes("Come back when you're sure you have everything.")
        |> close()

      true ->
        {ctx, choice} =
          ctx
          |> mes("[Boshuu]")
          |> mes("Oh, I see you're back with all the required materials.")
          |> mes("But before I start, I must ask you one more time.")
          |> mes(
            "Do you want to give me the materials you've brought and receive a Slotted Arm Guard instead?"
          )
          |> next()
          |> select(["No", "Yes"])

        if choice == 1 do
          ctx
          |> mes("[Boshuu]")
          |> mes("Ok")
          |> mes("Well, if you make up your mind again, come and see me.")
          |> close()
        else
          forge(ctx)
        end
    end
  end

  defp forge(ctx) do
    ctx =
      ctx
      |> mes("[Boshuu]")
      |> mes("All right!")
      |> mes("This should only take a second")
      |> mes("Bang Clang~  Bang Clang~")
      |> next()

    if not materials_ready?(ctx) or zeny(ctx) < @fee do
      ctx |> mes("HACK DETECTED") |> close()
    else
      ctx
      |> mes("[Boshuu]")
      |> mes("Here, it's finally complete.")
      |> mes("I present to you a Slotted Arm Guard.")
      |> mes("Come and find me whenever you're ready to request more.")
      |> charge()
      |> set_char_var(:ninbo, 0)
      |> unlock_guard()
      |> give_item(@slotted_arm_guard, 1)
      |> close()
    end
  end

  # A player who already owns the Guard but never met the quest yet gets the full
  # first-time hand-in.
  defp first_order(ctx) do
    {ctx, choice} =
      ctx
      |> set_char_var(:ninbo, 0)
      |> mes("[Boshuu]")
      |> mes("Oh~ You~!")
      |> mes(
        "Is what you have there the shield from overseas called a Guard? Let me take a look."
      )
      |> next()
      |> mes("[Boshuu]")
      |> mes("Unbelievable!! It is~!")
      |> mes("If all shields had a slot, they could become more effective than ever.")
      |> mes("How is it that I've only realised this now?")
      |> next()
      |> mes("[Boshuu]")
      |> mes("I'm the best out of the three craftsmen of Ninja tools called Murata Boshuu.")
      |> mes("I know how to create all the armor and shields of the eastern world.")
      |> next()
      |> mes("[Boshuu]")
      |> mes(
        "But because the armor I would create was so refined and high in defense, when people wearing my armor would fight again each other, neither side could win."
      )
      |> next()
      |> mes("[Boshuu]")
      |> mes("For that reason, I no longer make shields and armor.")
      |> next()
      |> mes("[Boshuu]")
      |> mes("Nowadays, all I do is collect shields and armor.")
      |> next()
      |> mes("[Boshuu]")
      |> mes("But life is kind of boring without crafting things.")
      |> next()
      |> mes("[Boshuu]")
      |> mes(
        "Since all I do is collect now, I feel like the creative spirit within me is disappearing."
      )
      |> next()
      |> mes("[Boshuu]")
      |> mes(
        "But at the sight of your shield, I feel like my sleeping spirit of creativity has awoken."
      )
      |> next()
      |> mes("[Boshuu]")
      |> mes(
        "I you want to, bring me an Arm Guard, a Slotted Guard, and 10,000 Zeny, and I'll make you a Slotted Arm Guard."
      )
      |> mes("How 'bout it? Would you like to obtain a Slotted Arm Guard?")
      |> next()
      |> select(["No, I'd rather not.", "Yes~!! Please make it for me!"])

    if choice == 1, do: brush_off(ctx), else: first_order_checks(ctx)
  end

  defp brush_off(ctx) do
    ctx
    |> mes("[Boshuu]")
    |> mes("Hmm, is that so?")
    |> mes("What a shame...")
    |> mes("Well, if you change your mind later, come back and see me.")
    |> close()
  end

  defp first_order_checks(ctx) do
    cond do
      not materials_ready?(ctx) ->
        ctx
        |> mes("[Boshuu]")
        |> mes("Hmm... It looks like you didn't bring me enough materials.")
        |> next()
        |> mes("[Boshuu]")
        |> mes("In order to make a Slotted Arm Guard,")
        |> mes("I need 1 Slotted Guard")
        |> mes("1 Arm Guard, and")
        |> mes("10,000 Zeny.")
        |> mes("Come back when you're sure you have everything.")
        |> close()

      zeny(ctx) < @fee ->
        ctx
        |> mes("[Boshuu]")
        |> mes("Hmm.. You brought plenty of materials, but you're short on zeny.")
        |> next()
        |> mes("[Boshuu]")
        |> mes("In order to make a Slotted Arm Guard,")
        |> mes("I need 1 Slotted Guard")
        |> mes("1 Arm Guard, and")
        |> mes("10,000 Zeny.")
        |> mes("Come back when you're sure you have everything.")
        |> close()

      true ->
        {ctx, choice} =
          ctx
          |> mes("[Boshuu]")
          |> mes("Oh, You've brought me the needed materials.")
          |> mes("Before I begin, let me ask one final time...")
          |> mes("Will you give me the materials you've gathered,")
          |> mes("and in turn, receive a Slotted Arm Guard?")
          |> next()
          |> select(["No", "Yes"])

        if choice == 1,
          do: keep_materials(ctx, "If you ever make up your mind"),
          else: first_forge(ctx)
    end
  end

  defp first_forge(ctx) do
    ctx =
      ctx
      |> mes("[Boshuu]")
      |> mes("All right!")
      |> mes("This should only take a second")
      |> mes("Bang Clang ~Bang Clang ~")
      |> next()

    if not materials_ready?(ctx) or zeny(ctx) < @fee do
      ctx |> mes("HACK DETECTED") |> close()
    else
      ctx
      |> mes("[Boshuu]")
      |> mes("Here, it's finally complete.")
      |> mes("I present to you a Slotted Arm Guard.")
      |> mes("If you ever want to ask me to make you more items, feel free to come back anytime.")
      |> charge()
      |> unlock_guard()
      |> give_item(@slotted_arm_guard, 1)
      |> close()
    end
  end

  defp repeat_order(ctx) do
    {ctx, choice} =
      ctx
      |> set_char_var(:ninbo, 0)
      |> mes("[Boshuu]")
      |> mes("Oh~ I see you've come back.")
      |> mes("Is it because you need another slotted Arm Guard?")
      |> next()
      |> select(["Nope, not really.", "Yes, make me another one."])

    if choice == 1, do: not_really(ctx), else: repeat_checks(ctx)
  end

  defp not_really(ctx) do
    ctx
    |> mes("[Boshuu]")
    |> mes("Hmmph~ You sure a weird one.")
    |> mes("Well, I'll see you later~")
    |> close()
  end

  defp repeat_checks(ctx) do
    cond do
      not materials_ready?(ctx) ->
        ctx
        |> mes("[Boshuu]")
        |> mes("Hmm... It looks like you didn't bring me enough materials.")
        |> mes("In order to make a Slotted Arm Guard,")
        |> mes("I need 1 Slotted Guard")
        |> mes("1 Arm Guard, and")
        |> mes("10,000 Zeny.")
        |> mes("Come back when you're sure you have everything.")
        |> close()

      zeny(ctx) < @fee ->
        ctx
        |> mes("[Boshuu]")
        |> mes("Hmm.. You brought plenty of materials, but you're short on zeny.")
        |> next()
        |> mes("[Boshuu]")
        |> mes("In order to create one Slotted Arm Guard,")
        |> mes("I need 1 Slotted Guard, 1 Arm Guard, and 10,000 Zeny.")
        |> mes("Come back when you're sure you have everything.")
        |> close()

      true ->
        {ctx, choice} =
          ctx
          |> mes("[Boshuu]")
          |> mes("Oh, You've brought me the needed materials.")
          |> mes("Before I begin, let me ask one final time...")
          |> mes(
            "Will you give me the materials you've gathered, and in turn, receive a slotted Arm Guard?"
          )
          |> next()
          |> select(["No", "Yes"])

        if choice == 1,
          do: keep_materials(ctx, "If you ever make up your mind"),
          else: repeat_forge(ctx)
    end
  end

  defp repeat_forge(ctx) do
    ctx =
      ctx
      |> mes("[Boshuu]")
      |> mes("All right!")
      |> mes("This should only take a second")
      |> mes("Bang Clang ~Bang Clang ~")
      |> next()
      |> mes("[Boshuu]")
      |> mes("Here, it's finally complete.")
      |> mes("I present to you a Slotted Arm Guard.")
      |> next()

    if not materials_ready?(ctx) or zeny(ctx) < @fee do
      ctx |> mes("HACK DETECTED") |> close()
    else
      ctx
      |> mes("[Boshuu]")
      |> mes("If you ever want to ask me to make you more items, feel free to come back anytime.")
      |> charge()
      |> give_item(@slotted_arm_guard, 1)
      |> close()
    end
  end

  defp keep_materials(ctx, closing_line) do
    ctx
    |> mes("[Boshuu]")
    |> mes("Ok")
    |> mes(closing_line)
    |> mes("come and find me again.")
    |> close()
  end

  defp materials_ready?(ctx) do
    count_item(ctx, @slotted_guard) >= 1 and count_item(ctx, @arm_guard) >= 1
  end

  # The trade consumes the Slotted Guard before the Arm Guard, then the fee.
  defp charge(ctx) do
    ctx
    |> delitem(@slotted_guard, 1)
    |> delitem(@arm_guard, 1)
    |> pay_zeny(@fee)
  end

  defp guard_unlocked?(ctx), do: unlocked?(get_char_var(ctx, :MISC_QUEST, 0))

  defp unlock_guard(ctx) do
    set_char_var(ctx, :MISC_QUEST, :erlang.bor(get_char_var(ctx, :MISC_QUEST, 0), @guard_bit))
  end

  defp unlocked?(quest_bits), do: Rathena.truthy?(:erlang.band(quest_bits, @guard_bit))
end
