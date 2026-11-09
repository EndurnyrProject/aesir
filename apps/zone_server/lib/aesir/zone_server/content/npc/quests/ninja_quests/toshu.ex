defmodule Aesir.ZoneServer.Content.Npc.Quests.NinjaQuests.Toshu do
  @moduledoc """
  Murata Toshu, the middle of the three eastern craftsmen, slots an Improved Arm Guard.

  ## Behavior

  - Turns any non-Ninja away.
  - Offers the slotting service for 1 Improved Arm Guard, 1 Slotted Buckler and
    40,000 Zeny, warning that the attempt can break the materials.
  - Takes the materials and Zeny, then rolls `rand(5)`: 1 and 2 hand back a
    Bomber Steak as consolation, every other roll yields the slotted Advanced
    Arm Guard.

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
    spawn: [%{map: "que_ng", x: 27, y: 18, dir: 3, sprite: 709, name: "Toshu", scope: :shared}]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @arm_guard 2104
  @slotted_buckler 2119
  @slotted_arm_guard 2120
  @herbal_tea 12043
  @fee 40_000

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if Rathena.job_id(base_class(ctx)) == Rathena.job_id(:ninja) do
      offer(ctx)
    else
      turn_away(ctx)
    end
  end

  defp turn_away(ctx) do
    ctx
    |> mes("[Toshu]")
    |> mes("How are you~")
    |> mes("My young friend~")
    |> mes(
      "I am one of the three brothers of the eastern world who craft armor. The name is Murata Toshu."
    )
    |> next()
    |> mes("[Toshu]")
    |> mes("I've learned how to slot things from a land overseas.")
    |> mes("I'm thinking about earning some money using this ability.")
    |> next()
    |> mes("[Toshu]")
    |> mes("But you don't seem like the kind of customer which I can do business with...")
    |> close()
  end

  defp offer(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Toshu]")
      |> mes("How are you, my young friend~")
      |> mes(
        "I'm the middle brother of the three brothers in charge of crafting shields in the east."
      )
      |> mes("They call me Murata Toshu.")
      |> next()
      |> mes("[Toshu]")
      |> mes(
        "I learned how to slot things from overseas, so I'm thinking about earning some money with that ability part time."
      )
      |> next()
      |> mes("[Toshu]")
      |> mes("If you want, I can create a Slotted Improved Arm Guard if you bring me")
      |> mes("1 Improved Arm Guard, 1 Slotted Buckler")
      |> mes("and 40,000 Zeny.")
      |> next()
      |> mes("[Toshu]")
      |> mes(
        "By the way, I'm sorry to say this, but there's a chance I might break your materials and fail slotting the Improved Arm Guard, so you might want to think about it."
      )
      |> mes("How 'bout it? Do we have a deal?")
      |> next()
      |> select(["No. I don't want to do this.", "Yes! Let's do this!"])

    if choice == 1, do: decline(ctx), else: check_materials(ctx)
  end

  defp decline(ctx) do
    ctx
    |> mes("[Toshu]")
    |> mes("Ok.")
    |> mes("Of course, the shields are important to you.")
    |> mes("If you decide to go foward with this afterwards, come and find me.")
    |> close()
  end

  defp check_materials(ctx) do
    cond do
      count_item(ctx, @arm_guard) < 1 or count_item(ctx, @slotted_buckler) < 1 ->
        missing_lines(ctx)

      zeny(ctx) < @fee ->
        short_zeny_lines(ctx)

      true ->
        warn_failure(ctx)
    end
  end

  defp missing_lines(ctx) do
    ctx
    |> mes("[Toshu]")
    |> mes("It doesn't look like you brought me enough materials.")
    |> mes("The required materials are 1 Slotted Buckler")
    |> mes("1 Improved Arm Guard, and")
    |> mes("40,000 Zeny.")
    |> mes("You must bring me the right number of materials and Zeny.")
    |> mes("Don't forget that.")
    |> close()
  end

  defp short_zeny_lines(ctx) do
    ctx
    |> mes("[Toshu]")
    |> mes("It looks like you brought the right amount of materials.")
    |> mes("However.. you didn't bring enough Zeny.")
    |> mes("The required materials are 1 Slotted Buckler")
    |> mes("1 Improved Arm Guard, and 40,000 Zeny.")
    |> mes("You must bring me the right number of materials and Zeny.")
    |> mes("Don't forget that.")
    |> close()
  end

  defp warn_failure(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Toshu]")
      |> mes("Hmm. materials and zeny checked!")
      |> mes("Time to begin my part.")
      |> mes("Just to warn you..")
      |> next()
      |> mes("[Toshu]")
      |> mes(
        "While I am in production, I may fail to create your gear, so you may want to think it over."
      )
      |> next()
      |> mes("[Toshu]")
      |> mes("Do you want me to produce your gear, even if there's a chance I may fail?")
      |> next()
      |> select(["I think I better back off. Sob..", "Yes! Let's try anyway!"])

    if choice == 1, do: back_off(ctx), else: craft(ctx)
  end

  defp back_off(ctx) do
    ctx
    |> mes("[Toshu]")
    |> mes("Ok.")
    |> mes("Well, come back later when you've got the guts to try.")
    |> mes("Erherherherher~")
    |> close()
  end

  defp craft(ctx) do
    ctx =
      ctx
      |> mes("[Toshu]")
      |> mes("OK! I have your order!")
      |> mes("Just wait 3 seconds!!")
      |> mes("Clink Clank~!Clink Clank~!!")
      |> mes("Sweep Sweep~ Saw Saw~")
      |> next()

    if count_item(ctx, @arm_guard) < 1 or count_item(ctx, @slotted_buckler) < 1 or
         zeny(ctx) < @fee do
      ctx |> mes("HACK DETECTED") |> close()
    else
      ctx
      |> delitem(@arm_guard, 1)
      |> delitem(@slotted_buckler, 1)
      |> pay_zeny(@fee)
      |> roll_slot()
    end
  end

  # rAthena rolls `rand(5)`: 1 and 2 break the shield, 0, 3 and 4 succeed.
  defp roll_slot(ctx) do
    if (:rand.uniform(5) - 1) in [1, 2] do
      ctx
      |> give_item(@herbal_tea, 1)
      |> mes("[Toshu]")
      |> mes("Aaah!!!")
      |> mes("Ah.. this")
      |> mes("is bad news.")
      |> mes("Slotting the shield has failed")
      |> mes("as I feared.")
      |> mes("I'm very sorry about this.")
      |> mes("Eat this and cheer up.")
      |> close()
    else
      ctx
      |> give_item(@slotted_arm_guard, 1)
      |> mes("[Toshu]")
      |> mes("Hmm~~ Looks like everything went all right.")
      |> mes("Here is your completed Slotted")
      |> mes("Improved Arm Guard.")
      |> mes(
        "I was nervous that it might fail, but hey, there's a reason why I'm called a Craftsman, right?"
      )
      |> mes("If you need me again, come and seek me.")
      |> close()
    end
  end
end
