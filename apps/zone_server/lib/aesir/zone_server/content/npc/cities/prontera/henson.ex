defmodule Aesir.ZoneServer.Content.Npc.Cities.Prontera.Henson do
  @moduledoc """
  Teaches visitors about offensive and defensive Acolyte and Priest skills.

  ## Behavior

  - Explains Divine Protection, Demon Bane, Decrease AGI, Signum Crusis, Pneuma, Ruwach, and Teleport.
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
        y: 71,
        dir: 0,
        sprite: 120,
        name: "Henson",
        scope: :shared,
        unique_name: "Henson#pront"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Henson]")
    |> mes(
      "We Priests and Acolytes are not only limited to easing the suffering of our fellow man..."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "We also mete swift and merciless punishment to the forces of evil. Well, purifying any poor souls that may have been turned into the Undead is also another duty."
    )
    |> next()
    |> mes("[Henson]")
    |> mes("Did you have any questions about Acolyte and Priest skills?")
    |> choose_skill()
  end

  defp choose_skill(ctx) do
    {ctx, choice} =
      ctx
      |> next()
      |> select([
        "About Divine Protection",
        "About Demon Bane",
        "About Decrease AGI",
        "About Signum Crusis ",
        "About Pneuma",
        "About Ruwach",
        "About Teleport",
        "End conversation."
      ])

    case choice do
      1 -> ctx |> explain_divine_protection() |> choose_skill()
      2 -> ctx |> explain_demon_bane() |> choose_skill()
      3 -> ctx |> explain_decrease_agi() |> choose_skill()
      4 -> ctx |> explain_signum_crusis() |> choose_skill()
      5 -> ctx |> explain_pneuma() |> choose_skill()
      6 -> ctx |> explain_ruwach() |> choose_skill()
      7 -> ctx |> explain_teleport() |> choose_skill()
      8 -> end_conversation(ctx)
      _ -> choose_skill(ctx)
    end
  end

  defp explain_divine_protection(ctx) do
    ctx
    |> mes("[Henson]")
    |> mes(
      "If you want to permanently improve your Defense against the Undead, learn ^6666CCDivine Protection^000000."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "Learning Divine Protection to certain levels will also allow you to learn other skills, like ^6666CCAngelus^000000 and ^6666CCBlessing^000000, which Garnet can explain."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "When you learn ^6666CCLevel 3 Divine Protection^000000, you will then be able to learn the ^6666CCDemon Bane^000000 skill."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "With ^6666CCDemon Bane^000000, the damage of your attacks against the Undead will be increased. Permanently."
    )
  end

  defp explain_demon_bane(ctx) do
    ctx
    |> mes("[Henson]")
    |> mes(
      "^6666CCDemon Bane^000000 increases the damage you will inflict upon the Undead. Permanently."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "First, you'll need to learn ^6666CCLevel 3 Divine Protection^000000 to be able to learn Demon Bane, so keep that in mind."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "When you learn ^6666CCLevel 3 Demon Bane^000000, you will be able to learn ^6666CCSignum Crusis^000000, which lowers the Defense of Undead monsters, as well as monsters with the Dark property."
    )
  end

  defp explain_decrease_agi(ctx) do
    ctx
    |> mes("[Henson]")
    |> mes(
      "Using ^6666CCDecrease AGI^000000 on monsters will slow their movement, attack speed, and the rate at which they can evade your own attacks. That way, you can maim them properly."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "Remember, you must first learn ^6666CCLevel 2 Increase AGI^000000 if you want to be able to learn the Decrease AGI skill."
    )
  end

  defp explain_signum_crusis(ctx) do
    ctx
    |> mes("[Henson]")
    |> mes(
      "The ^6666CCSignum Crusis^000000 skill lowers the Defense of monsters with the Undead or Dark properties. It has a wide range and can be quite powerful."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "However, it's a very difficult skill to use, and it has a relatively low success rate. But, do not despair if this skill is not successful all the time."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "When it does work, it will give you a great battle advantage. Remember, you will ^6666CCLevel 3 Demon Bane^000000 to acquire this skill."
    )
  end

  defp explain_pneuma(ctx) do
    ctx
    |> mes("[Henson]")
    |> mes(
      "The ^6666CCPneuma^000000 allows you to generate a barrier that will block all long-range attacks in a certain range, creating a zone that will protect you from monsters that attack from a distance."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "In order to become ready to learn Pneuma, you must first completely master the ^6666CCWarp Portal^000000 skill."
    )
  end

  defp explain_ruwach(ctx) do
    ctx
    |> mes("[Henson]")
    |> mes(
      "Nothing can escape the eyes of the Holy! ^6666CCRuwach^000000 allows you to see monsters, as well as other adventurers, that are hidden or invisible."
    )
    |> next()
    |> mes("[Henson]")
    |> mes("Once you learn Ruwach, you will be able to learn the ^6666CCTeleport^000000 skill.")
  end

  defp explain_teleport(ctx) do
    ctx
    |> mes("[Henson]")
    |> mes(
      "First, you must learn the ^6666CCRuwach^000000 skill in order to learn how to Teleport."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "The ^6666CCTeleport^000000 skill teleports you to a random location in the field or city which you are currently in. Teleport will prove useful for quick escapes, but where you may end up is... unpredictable."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "Once the Teleport skill is mastered, you can Teleport to the latest Save Point that you have made with a Kafra Employee. I do not know why it is that way, but the Lord works in mysterious ways."
    )
    |> next()
    |> mes("[Henson]")
    |> mes(
      "When Teleport is mastered, you can also learn the ^6666CCWarp Portal^000000 skill. Ask Garnet if you wish to know more about Warp Portal."
    )
  end

  defp end_conversation(ctx) do
    ctx
    |> mes("[Henson]")
    |> mes(
      "If you wish to understand more about an Acolyte or Priest skill, you are welcome to visit me at any time."
    )
    |> close()
  end
end
