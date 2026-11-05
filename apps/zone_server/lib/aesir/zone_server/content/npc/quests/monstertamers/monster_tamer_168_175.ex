defmodule Aesir.ZoneServer.Content.Npc.Quests.Monstertamers.MonsterTamer168175 do
  @moduledoc """
  Al de Baran's monster tamer YuU, who turns ordinary headwear into the pet versions of
  those items.

  ## Behavior

  - Explains the six recipes and the components each one needs
  - With the components in hand, consumes them and hands over the pet item: Skull Helm
    (10001), Monster Oxygen Mask (10002), Silk Ribbon (10007), Stellar Hairpin (10011),
    Tiny Egg Shell (10012) or Rocker Glasses (10014)
  - Rocker Glasses additionally cost 400 Zeny and need 2 Zargon
  - Without the components, states what the recipe needs and closes without taking anything

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Darkchild
    - x[tsk]
    - Lupus
    - Silent
    - SinSloth
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "aldeba_in",
        x: 168,
        y: 175,
        dir: 4,
        sprite: 125,
        name: "Monster Tamer",
        scope: :shared,
        unique_name: "Monster Tamer#alde"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[YuU]")
      |> mes(
        "You must be looking for monster items! In making monster items, there is no monster tamer in Rune-Midgarts that's better than me."
      )
      |> next()
      |> mes("[YuU]")
      |> mes("I can make all sorts of neat things for your Cute Pet monster.")
      |> mes("Just ask~")
      |> next()
      |> select([
        "^3355FF' Monster Taming '^000000?",
        "Order ^3355FF' Skull Helm '^000000",
        "Order ^3355FF' Monster Oxygen Mask '^000000",
        "Order ^3355FF' Silk Ribbon '^000000",
        "Order ^3355FF' Stellar Hairpin '^000000",
        "Order ^3355FF' Tiny Egg Shell '^000000",
        "Order ^3355FF' Rocker Glasses '^000000",
        "Cancel"
      ])

    case choice do
      1 -> explain_recipes(ctx)
      2 -> skull_helm(ctx)
      3 -> monster_oxygen_mask(ctx)
      4 -> silk_ribbon(ctx)
      5 -> stellar_hairpin(ctx)
      6 -> tiny_egg_shell(ctx)
      7 -> rocker_glasses(ctx)
      8 -> undecided(ctx)
      _ -> ctx
    end
  end

  @spec explain_recipes(Ctx.t()) :: Ctx.t()
  defp explain_recipes(ctx) do
    ctx
    |> mes("[YuU]")
    |> mes("The monster items that are")
    |> mes("necessary to communicate")
    |> mes("with monsters...")
    |> mes("These are a must have!")
    |> mes("We Monster Tamer guild members'")
    |> mes("have a very reasonable offer.")
    |> next()
    |> mes("[YuU]")
    |> mes(
      "We provide a system that allows you to get your hands on these cool items with less of the hassle!"
    )
    |> mes("Silk Ribbon !")
    |> mes("Monster Oxygen Mask !")
    |> mes("Skull Helm !")
    |> next()
    |> mes("[YuU]")
    |> mes("Stellar Hairpin !")
    |> mes("Tiny Egg Shell !!")
    |> mes("Rocker Glasses !!!")
    |> next()
    |> mes("[YuU]")
    |> mes("1 Skull Helm requires")
    |> mes("1 ^3355FFBone Helm^000000")
    |> next()
    |> mes("[YuU]")
    |> mes("1 Monster Oxygen Mask requires")
    |> mes("1 ^3355FFOxygen Mask^000000.")
    |> next()
    |> mes("[YuU]")
    |> mes("1 Silk Ribbon requires")
    |> mes("1 ^3355FFRibbon^000000.")
    |> next()
    |> mes("[YuU]")
    |> mes("1 Stellar Hairpin requires")
    |> mes("1 ^3355FFStellar^000000.")
    |> next()
    |> mes("[YuU]")
    |> mes("1 Tiny Egg Shell requires")
    |> mes("1 ^3355FFEgg Shell^000000.")
    |> next()
    |> mes("[YuU]")
    |> mes("1 Rocker Glassess requires")
    |> mes("^3355FF400 Zeny^000000,")
    |> mes("2 ^3355FFZargon^000000 and")
    |> mes("1 ^3355FFRibbon^000000. ")
    |> next()
    |> mes("[YuU]")
    |> mes("Try your best to find these items so that you can raise a Cute Monster! Good luck!")
    |> close()
  end

  @spec skull_helm(Ctx.t()) :: Ctx.t()
  defp skull_helm(ctx) do
    ctx =
      ctx
      |> mes("[YuU]")
      |> mes(
        "This is an item far beyond what humans can wear! Its name? ^3355FFSkull Helm^000000! Disgusting on humans, but cute on monsters."
      )
      |> next()

    if count_item(ctx, 5017) > 0 do
      ctx
      |> mes("[YuU]")
      |> mes(
        "Oh! You have all the items necessary to make Skull Helm! Good, good! With all my pride as a monster tamer, I will make it for you right away."
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Got to rub")
      |> mes("this Bone Helm")
      |> mes("just right...")
      |> next()
      |> mes("[YuU]")
      |> mes("Okay. All done!")
      |> mes("Please take this for")
      |> mes("the cute monster you")
      |> mes("are raising.")
      |> mes("Skull Helm!")
      |> delitem(5017, 1)
      |> give_item(10001, 1)
      |> close()
    else
      ctx
      |> mes("[YuU]")
      |> mes(
        "For the monster owner that loves to spoil his or her monster, we provide one way to make a Skull Helm."
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Just bring me...")
      |> mes("^3355FF1 Bone Helm^000000!")
      |> mes("With all my pride as a monster tamer, I will make it for you!")
      |> close()
    end
  end

  @spec monster_oxygen_mask(Ctx.t()) :: Ctx.t()
  defp monster_oxygen_mask(ctx) do
    ctx =
      ctx
      |> mes("[YuU]")
      |> mes(
        "This item is far beyond what humans can wear. Its name? ^3355FFMonster Oxygen Mask^000000! Show your monster that you care with this special gift."
      )
      |> next()

    if count_item(ctx, 5004) > 0 do
      ctx
      |> mes("[YuU]")
      |> mes(
        "Oh! You have all the items necessary to make 1 Monster Oxygen Mask! Good, Good! With all my pride as a monster tamer, I will make it for you right away."
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Got to pull apart")
      |> mes("this Oxygen Mask")
      |> mes("just right...")
      |> next()
      |> mes("^3355FF*Flip flop... Zowie!*^000000")
      |> next()
      |> mes("[YuU]")
      |> mes("Okay. All done.")
      |> mes("Please take it for")
      |> mes("the cute monster you")
      |> mes("are raising...")
      |> mes("Monster Oxygen Mask!")
      |> delitem(5004, 1)
      |> give_item(10002, 1)
      |> close()
    else
      ctx
      |> mes("[YuU]")
      |> mes(
        "For the monster owner that wants to pamper his or her monster with its very own breathing apparatus, we provide a way to create 1 Monster Oxygen Mask!"
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Bring me...")
      |> mes("^3355FF1 Oxygen Mask^000000.")
      |> mes("With all my pride as a monster tamer, I will make it for you right away!")
      |> close()
    end
  end

  @spec silk_ribbon(Ctx.t()) :: Ctx.t()
  defp silk_ribbon(ctx) do
    ctx =
      ctx
      |> mes("[YuU]")
      |> mes(
        "This is not an item that a normal human would dare to wear! Its name? ^3355FFSilk Ribbon^000000! Its perfect for monsters!"
      )
      |> next()

    if count_item(ctx, 2208) > 0 do
      ctx
      |> mes("[YuU]")
      |> mes(
        "Oh! You have all the items necessary to make 1 Silk Ribbon! Good, good! With all my pride as a monster tamer, I will make it for you right away!"
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Got to unravel")
      |> mes("this ribbon")
      |> mes("just right...")
      |> next()
      |> mes("[YuU]")
      |> mes("Okay. All done.")
      |> mes("Please take it for")
      |> mes("the cute monster you")
      |> mes("are raising.")
      |> mes("Silk Ribbon!")
      |> delitem(2208, 1)
      |> give_item(10007, 1)
      |> close()
    else
      ctx
      |> mes("[YuU]")
      |> mes(
        "For the monster owner that is fond of elegantly dressing their pets, we provide a way to create 1 Silk Ribbon!"
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Just bring me...")
      |> mes("^3355FF1 Ribbon^000000!")
      |> mes("with all my pride as a monster tamer, I will make it for you!")
      |> close()
    end
  end

  @spec stellar_hairpin(Ctx.t()) :: Ctx.t()
  defp stellar_hairpin(ctx) do
    ctx =
      ctx
      |> mes("[YuU]")
      |> mes(
        "This is an item far beyond the fashion sense of humans! Its name? ^3355FFStellar Hairpin^000000! It's dangerous for humans to wear, but fashionable of monsters."
      )
      |> next()

    if count_item(ctx, 2294) > 0 do
      ctx
      |> mes("[YuU]")
      |> mes(
        "Oh! You have all the items necessary to make 1 Stellar! Good, good! With all my pride as a monster tamer, I will make it for you right away."
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Now, if I can")
      |> mes("only peel this")
      |> mes("without breaking it...")
      |> next()
      |> mes("^3355FF*Shine shine*^000000")
      |> next()
      |> mes("[YuU]")
      |> mes("Okay. All done.")
      |> mes("Please take it for")
      |> mes("the cute monster you")
      |> mes("are raising")
      |> mes("Stellar Hairpin!")
      |> delitem(2294, 1)
      |> give_item(10011, 1)
      |> close()
    else
      ctx
      |> mes("[YuU]")
      |> mes(
        "For the monster owner that want the best for their cute pet, we provide a wait to create 1 Stellar Hairpin!"
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Just bring me...")
      |> mes("^3355FF 1 Stellar !^000000")
      |> mes("with all my pride as a monster tamer, I will make it for you!")
      |> close()
    end
  end

  @spec tiny_egg_shell(Ctx.t()) :: Ctx.t()
  defp tiny_egg_shell(ctx) do
    ctx =
      ctx
      |> mes("[YuU]")
      |> mes(
        "This is far beyond what the headwear that humans can don. Its name? ^3355FFTiny Egg Shell^000000! It has the shine of marble and the glow of youth!"
      )
      |> next()

    if count_item(ctx, 5015) > 0 do
      ctx
      |> mes("[YuU]")
      |> mes(
        "Oh! You have all the items necessary to make 1 Tiny Egg Shell! Good, good! With all my pride as a monster tamer, I will make it for you right away!"
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Got to")
      |> mes("shatter this")
      |> mes("just right...")
      |> next()
      |> mes("^3355FF*Scrub scrub squeeze squeeze*^000000")
      |> next()
      |> mes("[YuU]")
      |> mes("Okay. All done.")
      |> mes("Please take it for")
      |> mes("the cute monster you")
      |> mes("are raising")
      |> mes("Tiny Egg Shell!")
      |> delitem(5015, 1)
      |> give_item(10012, 1)
      |> close()
    else
      ctx
      |> mes("[YuU]")
      |> mes(
        "For the monster owner that is fond of eggs and fonder of egg shells, we provide a way to create 1 Tiny Egg Shell!"
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Just bring me...")
      |> mes("^3355FF1 Tiny Egg Shell^000000!")
      |> mes("with all my pride as a monster tamer, I will make it for you!")
      |> close()
    end
  end

  @spec rocker_glasses(Ctx.t()) :: Ctx.t()
  defp rocker_glasses(ctx) do
    ctx =
      ctx
      |> mes("[YuU]")
      |> mes(
        "Ah yes, this is eyewear far beyond the glasses of normal humans. Its name? ^3355FFRocker Glasses^000000! Suave eyewear for suave monsters~"
      )
      |> next()

    if count_item(ctx, 912) > 1 and count_item(ctx, 2208) > 0 and zeny(ctx) > 399 do
      ctx
      |> mes("[YuU]")
      |> mes(
        "Oh! You have all the items necessary to make 1 Rocker Glasses! Good, good! With all my pride as a monster tamer, I will make it for you right away!"
      )
      |> next()
      |> mes("[YuU]")
      |> mes(
        "Okay, now all I gotta do is take this Zargon and, um, make glasses lenses out of them. Somehow."
      )
      |> next()
      |> mes("^3355FF*Squeak squeak crush snap*^000000")
      |> next()
      |> mes("[YuU]")
      |> mes("Whew! Lucky!")
      |> mes("Somehow I did it.")
      |> mes("Please take this for")
      |> mes("the cute monster you")
      |> mes("are raising.")
      |> mes("Rocker Glasses!")
      |> delitem(912, 2)
      |> delitem(2208, 1)
      |> pay_zeny(400)
      |> give_item(10014, 1)
      |> close()
    else
      ctx
      |> mes("[YuU]")
      |> mes(
        "For the monster owner that likes monster glasses, we provide a way to make Rocker Glasses!"
      )
      |> next()
      |> mes("[YuU]")
      |> mes("Just bring me...")
      |> mes("^3355FF2 Zargon^000000")
      |> mes("^3355FF1 Ribbon^000000 and")
      |> mes("^3355FF400 zeny^000000. ")
      |> mes("I will make it for you, with all my pride as a monster tamer!")
      |> close()
    end
  end

  @spec undecided(Ctx.t()) :: Ctx.t()
  defp undecided(ctx) do
    ctx
    |> mes("[YuU]")
    |> mes("Ah...!")
    |> mes("You must have not decided which Monster you want to raise.")
    |> next()
    |> mes("[YuU]")
    |> mes(
      "Definitely not a decision to be made carelessly! Your pet monster will accompany you throughout your life. Please take your time and return when you have decided."
    )
    |> close()
  end
end
