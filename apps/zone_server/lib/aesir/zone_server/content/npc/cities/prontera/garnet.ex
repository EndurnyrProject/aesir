defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Garnet do
  @moduledoc """
  Teaches visitors about supportive Acolyte and Priest skills.

  ## Behavior

  - Explains Heal, Cure, Increase AGI, Angelus, Blessing, and Warp Portal.
  - Repeats the skill menu until the visitor ends the conversation.

  ## Credits

  - Original from rAthena, authors and Contributors
    - rAthena Dev Team

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "prt_church",
        x: 103,
        y: 76,
        dir: 0,
        sprite: 67,
        name: "Garnet",
        scope: :shared,
        unique_name: "Garnet#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Garnet]")
    |> mes("Hello there~")
    |> mes("Are you interested in learning more about helping and supporting other people?")
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "The Acolytes and Priests trained in this church can heal people, cure them of certain conditions, and even awaken the battle potential of other adventurers."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Go and ahead and ask if you have any questions about skills for Acolytes and Priests."
    )
    |> choose_skill()
  end

  defp choose_skill(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> select([
        "About Heal",
        "About Cure",
        "About Increase AGI",
        "About Angelus",
        "About Blessing",
        "About Warp Portal",
        "End Conversation"
      ])

    case choice do
      1 ->
        ctx |> explain_heal() |> choose_skill()

      2 ->
        ctx |> explain_cure() |> choose_skill()

      3 ->
        ctx |> explain_increase_agi() |> choose_skill()

      4 ->
        ctx |> explain_angelus() |> choose_skill()

      5 ->
        ctx |> explain_blessing() |> choose_skill()

      6 ->
        ctx |> explain_warp_portal() |> choose_skill()

      7 ->
        ctx
        |> mes("[#{char_name(ctx, 0)}]")
        |> mes("Alright, I've")
        |> mes("heard enough.")
        |> close()

      _ ->
        choose_skill(ctx)
    end
  end

  defp explain_heal(ctx) do
    ctx
    |> mes("[Garnet]")
    |> mes(
      "You can recover your own HP with the ^6666CCHeal^000000 skill. Healing is one of the most important ways you can help your friends in battle."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Even though our powers are usually used to heal others, you can actually use the ^6666CCHeal^000000 skill to hurt Undead monsters."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Just remember to hold down the ^6666CCShift^000000 key when you use Cure or Heal on Undead monsters. Just be sure to hurt the monsters though, and don't use it to help monsters."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Later, if you've learned ^6666CCHeal^000000 as an Acolyte, you can learn ^6666CCSanctuary^000000 if you become a Priest."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Priests use ^6666CCSantuary^000000 to create an area which will restore the HP of you and your friends if you rest within the Sanctuary's area."
    )
  end

  defp explain_cure(ctx) do
    ctx
    |> mes("[Garnet]")
    |> mes(
      "Once you reach ^6666CCLevel 2 Heal^000000 as an Acolyte, you can learn ^6666CCCure^000000, which can be used to treat abnormal statuses."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "This skill can be such a life saver, since almost every abnormal status can be cured with the Cure skill. Just remember that you need ^6666CCLevel 2 Heal^000000 before you can learn Cure."
    )
  end

  defp explain_increase_agi(ctx) do
    ctx
    |> mes("[Garnet]")
    |> mes(
      "Now, the ^6666CCIncrease AGI^000000 skill can be used on you or your friends. For a while your AGI stat is increased, making you attack faster and dodge monster attacks more easily."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "If you're an Acolyte that wants to learn ^6666CCIncrease AGI^000000, you need to learn ^6666CCLevel 3 Heal^000000 first."
    )
  end

  defp explain_angelus(ctx) do
    ctx
    |> mes("[Garnet]")
    |> mes(
      "You can use ^6666CCAngelus^000000 to increase your Defense, as well as the Defense of other party members. Remember though, you can only use ^6666CCAngelus^000000 on other people if they are in your party."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Before you can learn Angelus, you will need to have ^6666CCLevel 3 Divine Protection^000000."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Also, if you keep learning Angelus, you'll eventually be able to learn ^6666CCKyrie Eleison^000000. That skill helps you evade initial attacks automatically."
    )
  end

  defp explain_blessing(ctx) do
    ctx
    |> mes("[Garnet]")
    |> mes(
      "^6666CCBlessing^000000 temporarily increases STR, DEX and INT. This skill will give you and your friends a great advantage in battle!"
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Before you can learn Blessing, you must first learn ^6666CCLevel 5 Divine Protection^000000."
    )
  end

  defp explain_warp_portal(ctx) do
    ctx
    |> mes("[Garnet]")
    |> mes(
      "^6666CCWarp Portal^000000 is a pretty complex skill, and you need to know some other skills before you can learn it."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "First, you need to learn ^6666CCRuwach^000000 which lets you see invisible monsters. After Ruwach, you will need to learn the ^6666CCTeleport^000000 skill."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Once you learn ^6666CCWarp Portal^000000, the level of the Warp Portal skill will determine how many warp destinations, or Warp Points, you can memorize."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "If you master the Warp Portal skill, you can have a maximum of 4 different Warp Points. But at least one Warp Point is designated as the Save Point that you've made with a Kafra Employee."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Well, it's a bit of hassle, but if you want to make a certain place one of your Warp Points, you need to be physically there first. Then, type in ^6666CC/memo^000000 into the command prompt."
    )
    |> next()
    |> mes("[Garnet]")
    |> mes(
      "Just so you know, you can't save a Warp Point inside of a dungeon. Oh, and don't forget, each time you make a Warp Portal, you must use 1 ^6666CCBlue Gemstone^000000 as a Catalyst."
    )
  end
end
