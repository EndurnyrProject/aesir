defmodule Aesir.ZoneServer.Content.Npc.PreRe.Jobs.Novice.Novice.Bruce do
  @moduledoc """
  Explains the six first job classes to novices who complete training.

  ## Behavior

  - Offers novices a repeatable menu describing the six first job classes.
  - Tracks job guidance progress and directs finished trainees to Hanson.

  ## Credits

  - Original from rAthena, authors: Dr.Evil and MasterOfMuppets.
  - Elixir adaptation: transpiled and refactored by an LLM.
  """

  use Aesir.ZoneServer.Npc,
    scope: :pre_renewal,
    spawn: [
      %{
        map: "new_1-4",
        x: 91,
        y: 22,
        dir: 4,
        sprite: 57,
        name: "Bruce",
        unique_name: "Bruce#nv"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    if class(ctx) == :novice do
      explain_jobs(ctx, get_char_var(ctx, :nov_3_swordman, 0))
    else
      ctx
    end
  end

  defp explain_jobs(ctx, 20) do
    ctx
    |> mes("[Bruce]")
    |> mes("Let me explain the")
    |> mes("First Job Classes")
    |> mes("to you once again.")
    |> mes("Which job did you")
    |> mes("have in mind?")
    |> next()
    |> choose_job(:returning)
  end

  defp explain_jobs(ctx, 40) do
    ctx
    |> mes("[Bruce]")
    |> mes("I'm sorry, but")
    |> mes("there's nothing")
    |> mes("more I can teach you.")
    |> next()
    |> mes("[Bruce]")
    |> mes("Hanson is waiting")
    |> mes("for you now. Good luck")
    |> mes("out there, young Novice.")
    |> close()
  end

  defp explain_jobs(ctx, _state) do
    name = char_name(ctx, 0)

    ctx
    |> mes("[Bruce]")
    |> mes("You've gone")
    |> mes("through quite")
    |> mes("a bit of trouble")
    |> mes("to finish all the")
    |> mes("training courses.")
    |> next()
    |> mes("[Bruce]")
    |> mes("Hello there,")
    |> mes("^A62A2A#{name}'^000000,")
    |> mes("pleased to meet you.")
    |> mes("I am Bruce of the")
    |> mes("Rune-Midgarts Kingdom.")
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "My duty is to assist you by teaching information about each First Job Class, so that you can decide which job you want to be."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes("The First Job Classes are")
    |> mes("^0000FFSwordman, Mage, Archer, Merchant, Thief and Acolyte^000000.")
    |> next()
    |> mes("[Bruce]")
    |> mes("So...")
    |> mes("Which job did")
    |> mes("you have in mind?")
    |> next()
    |> choose_job(:first_visit)
  end

  defp choose_job(ctx, visit) do
    {ctx, choice} =
      select(ctx, [
        "Swordman",
        "Mage",
        "Archer",
        "Merchant",
        "Thief",
        "Acolyte",
        "End conversation."
      ])

    case choice do
      1 -> ctx |> explain_swordman(visit) |> choose_job(visit)
      2 -> ctx |> explain_mage() |> choose_job(visit)
      3 -> ctx |> explain_archer() |> choose_job(visit)
      4 -> ctx |> explain_merchant() |> choose_job(visit)
      5 -> ctx |> explain_thief() |> choose_job(visit)
      6 -> ctx |> explain_acolyte() |> choose_job(visit)
      7 -> end_conversation(ctx)
      _ -> choose_job(ctx, visit)
    end
  end

  defp explain_swordman(ctx, :returning) do
    ctx
    |> mes("[Bruce]")
    |> mes("As the name implies, the")
    |> mes(
      "Swordman is an expert in wielding Swords. They can also use Spear weapons, but typically you don't see Spear wielding Swordmen very often."
    )
    |> explain_swordman_details(:returning)
  end

  defp explain_swordman(ctx, :first_visit) do
    ctx
    |> mes("[Bruce]")
    |> mes("As the name implies, the")
    |> mes(
      "Swordman is an expert in wielding Swords. They can also use Spear weapons, but typically you don't see Spear wielding Swordmen"
    )
    |> mes("very often.")
    |> explain_swordman_details(:first_visit)
  end

  defp explain_swordman_details(ctx, visit) do
    ctx
    |> next()
    |> mes("[Bruce]")
    |> explain_swordman_strength(visit)
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "The only weakness of the Swordman class is that they cannot use magic spells. However, this can be compensated by using weapons with an elemental attribute."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "One of the greatest benefits of being a Swordman is having an enormous amount of HP, meaning they can more easily withstand damage from their enemies."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "After learning some strong attack skills, the Swordman is almost unbeatable in a melee fight."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "In Ragnarok Online, Swordman generally takes the position of tanker, protecting characters of other classes from being attacked or hurt."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "A Swordman is the ideal character to take the position of party leader. When advancing to the Second Job Class, Swordmen can change their jobs to ^8E2323Knights^000000 or ^8E2323Crusaders^000000."
    )
    |> set_char_var(:nov_3_swordman, 20)
    |> next()
  end

  defp explain_swordman_strength(ctx, :returning) do
    mes(
      ctx,
      "Swordman possess strong physical strength, allowing them to equip heavy armor and weapons. Most weapon classes, except for bows and rods, can be equipped by the Swordman class."
    )
  end

  defp explain_swordman_strength(ctx, :first_visit) do
    mes(
      ctx,
      "Swordmen possess strong physical strength, allowing them to equip heavy armor and weapons. Most weapon classes, except for bows and rods, can be equipped by the Swordman class."
    )
  end

  defp explain_mage(ctx) do
    ctx
    |> mes("[Bruce]")
    |> mes(
      "The Mage class specializes in using the forces of Fire, Water, Earth and Lightning to attack their enemies."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "However, due to their weak physical strength, they are only allowed to equip Rods and Knives as weapons, and wear light armor for defense."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "Despite their physical weakness, they are able to do massive damage with their powerful spells. This fact alone attracts many people to join this class."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "In Ragnarok Online, the Mage takes a heavily offensive role in parties and is depended upon to deal great damage to enemies."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "When advancing to the Second Job Class, Mages can change their jobs to ^8E2323Wizards^000000 or ^8E2323Sages^000000."
    )
    |> set_char_var(:nov_3_swordman, 20)
    |> next()
  end

  defp explain_archer(ctx) do
    ctx
    |> mes("[Bruce]")
    |> mes(
      "The Archer class are experts in using Bow weapons, and are useful in parties for their long range attacks."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "Despite being physically weaker, Archers possess high accuracy with powerful long range bows. This allows them to attack and kill monsters from a safe distance."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "In Ragnarok Online, Archers have relatively little HP, but their long range attacks allow them to easily dispatch enemies before the enemy gets close enough to hurt them."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "When advancing to the Second Job Class, every Archer may advance to the ^8E2323Hunter^000000 class. Alternatively, male Archers may advance to become ^8E2323Bards^000000, and female Archers may become ^8E2323Dancers^000000."
    )
    |> set_char_var(:nov_3_swordman, 20)
    |> next()
  end

  defp explain_merchant(ctx) do
    ctx
    |> mes("[Bruce]")
    |> mes(
      "The Merchant class specializes in commerce. Due to the strong influence of the Merchant Guild, the Merchant class is attractive to those who wish to focus on earning Zeny."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "In Ragnarok Online, the Merchant class possesses various economic abilities. Merchants can learn to sell items to NPCs for higher prices, as well as receive discounts from NPCs."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes("In addition, Merchants may rent")
    |> mes(
      "a Cart that greatly expands their carrying capacity and allows them to open shops with their own items and prices."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "When advancing to the Second Job Class, Merchants can change their jobs to ^8E2323Blacksmiths^000000 or ^8E2323Alchemists^000000."
    )
    |> set_char_var(:nov_3_swordman, 20)
    |> next()
  end

  defp explain_thief(ctx) do
    ctx
    |> mes("[Bruce]")
    |> mes(
      "Thieves are experts at using Dagger class weapons. They strike quickly and easily evade attacks from their enemies."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "Thieves can learn skills that allow them to hide from their enemies, or steal items from monsters. They are also feared for their use of poison, which slowly weakens"
    )
    |> mes("their enemies.")
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "When advancing to the Second Job Class, Thieves can change their jobs to ^8E2323Assassins^000000 or ^8E2323Rogues^000000."
    )
    |> set_char_var(:nov_3_swordman, 20)
    |> next()
  end

  defp explain_acolyte(ctx) do
    ctx
    |> mes("[Bruce]")
    |> mes(
      "In Ragnarok Online, Acolytes act as messengers of God in Rune-Midgarts. They possess skills that support their allies, as well as the life saving Heal ability."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "The Acolyte's support abilities make them a welcome addition to any party. In difficult situations, the Acolyte's skills will ensure the survival of the party, allowing other members to focus on offense."
    )
    |> next()
    |> mes("[Bruce]")
    |> mes(
      "When advancing to the Second Job Class, Acolytes can change their jobs to ^8E2323Priests^000000 or ^8E2323Monks^000000."
    )
    |> set_char_var(:nov_3_swordman, 20)
    |> next()
  end

  defp end_conversation(ctx) do
    ctx
    |> mes("[Bruce]")
    |> mes("For more information,")
    |> mes("please visit the official")
    |> mes("Ragnarok Online website:")
    |> mes(" ")
    |> mes("^0000FFiro.ragnarokonline.com^000000.")
    |> next()
    |> mes("[Bruce]")
    |> mes("Hanson is waiting")
    |> mes("for you now. Good luck")
    |> mes("out there, young Novice.")
    |> close()
  end
end
