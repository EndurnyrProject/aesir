defmodule Aesir.ZoneServer.Content.Npc.Quests.Monstertamers.MonsterTamer do
  @moduledoc """
  Alberta's monster tamer Iwado, who brews the Monster Juice, Singing Flower and Wild
  Flower pet items from their component items.

  ## Behavior

  - Explains the three recipes: Monster Juice (1 Animal Gore and 2 Apple), Singing Flower
    (1 Singing Plant), Wild Flower (1 Fancy Flower and 1 Clover)
  - With the components in hand, consumes them and hands over the pet item: Monster Juice
    (626), Singing Flower (629) or Wild Flower (10009)
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
        map: "alberta_in",
        x: 173,
        y: 76,
        dir: 4,
        sprite: 125,
        name: "Monster Tamer",
        scope: :shared,
        unique_name: "Monster Tamer#alb"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Iwado]")
      |> mes(
        "This is the height of the era of Monster Taming! Don't you feel the need to gather monster items to be able to connect and to communicate with the Cute Monsters!?"
      )
      |> next()
      |> select([
        "^3355FF' Monster Taming '^000000 ?",
        "Order ^3355FF' Monster Juice '^000000",
        "Order ^3355FF' Singing Flower '^000000",
        "Order ^3355FF' Wild Flower '^000000",
        "Cancel"
      ])

    case choice do
      1 -> explain_recipes(ctx)
      2 -> monster_juice(ctx)
      3 -> singing_flower(ctx)
      4 -> wild_flower(ctx)
      5 -> undecided(ctx)
      _ -> ctx
    end
  end

  @spec explain_recipes(Ctx.t()) :: Ctx.t()
  defp explain_recipes(ctx) do
    ctx
    |> mes("[Iwado]")
    |> mes(
      "These monster items, necessary to communicate with monsters, are a must have! We, the members of the Monster Tamer Guild, have a very reasonable offer."
    )
    |> next()
    |> mes("[Iwado]")
    |> mes("We have a system that allows you")
    |> mes("to get your hands on these")
    |> mes("cool items without burden!")
    |> mes("Monster Juice !")
    |> mes("Singing Flower !")
    |> mes("Aaand....Wild Flower !")
    |> next()
    |> mes("[Iwado]")
    |> mes("To make")
    |> mes("Monster Juice, you need")
    |> mes("^3355FF1 Animal Gore^000000 and")
    |> mes("^3355FF2 Apple^000000.")
    |> next()
    |> mes("[Iwado]")
    |> mes("For 1 Singing Flower,")
    |> mes("you will need")
    |> mes("^3355FF1 Singing Plant^000000.")
    |> next()
    |> mes("[Iwado]")
    |> mes("If you want me to make")
    |> mes("1 Wild Flower,")
    |> mes("just give me")
    |> mes("^3355FF1 Fancy Flower^000000 and")
    |> mes("^3355FF1 Clover^000000.")
    |> close()
  end

  @spec monster_juice(Ctx.t()) :: Ctx.t()
  defp monster_juice(ctx) do
    ctx =
      ctx
      |> mes("[Iwado]")
      |> mes("This is an item that is far beyond")
      |> mes("anything we humans can drink!")
      |> mes("Its name? ^3355FFMonster Juice^000000 !!")
      |> mes("The extremely sour taste")
      |> mes("is perfect for monsters. . .")
      |> next()

    if count_item(ctx, 702) > 0 and count_item(ctx, 512) > 1 do
      brew_monster_juice(ctx)
    else
      monster_juice_recipe(ctx)
    end
  end

  @spec brew_monster_juice(Ctx.t()) :: Ctx.t()
  defp brew_monster_juice(ctx) do
    ctx
    |> mes("[Iwado]")
    |> mes(
      "Oh ! You have all the items to make 1 Monster Juice! Good, good! With all my pride as a monster tamer, I will make one for you right now."
    )
    |> next()
    |> mes("[Iwado]")
    |> mes("Got to twist these apples...")
    |> mes("Just right...")
    |> next()
    |> mes("^3355FF*Splash splash swoosh swhoosh splash splash*^000000")
    |> next()
    |> mes("[Iwado]")
    |> mes("Okay. All done!")
    |> mes("Please take it for the")
    |> mes("cute monster you")
    |> mes("are raising.")
    |> mes("Monster Juice!")
    |> delitem(512, 2)
    |> delitem(702, 1)
    |> give_item(626, 1)
    |> close()
  end

  @spec monster_juice_recipe(Ctx.t()) :: Ctx.t()
  defp monster_juice_recipe(ctx) do
    ctx
    |> mes("[Iwado]")
    |> mes("For the monster owner")
    |> mes("that loves to use monster juice...")
    |> mes("I have mastered the recipe for Monster Juice!")
    |> next()
    |> mes("[Iwado]")
    |> mes("If you bring me")
    |> mes("^3355FF1 Animal Gore^000000 and")
    |> mes("^3355FF2 Apple^000000")
    |> mes("With all my pride as a monster tamer, I will make it for you!")
    |> close()
  end

  @spec singing_flower(Ctx.t()) :: Ctx.t()
  defp singing_flower(ctx) do
    ctx =
      ctx
      |> mes("[Iwado]")
      |> mes("A flower with a song that is")
      |> mes("far beyond human comprehension!")
      |> mes("Its name? ^3355FFSinging Flower^000000!!")
      |> mes("A scent that makes you dizzy with pleasure. A perfect item for monsters...")
      |> next()

    if count_item(ctx, 707) > 0 do
      brew_singing_flower(ctx)
    else
      singing_flower_recipe(ctx)
    end
  end

  @spec brew_singing_flower(Ctx.t()) :: Ctx.t()
  defp brew_singing_flower(ctx) do
    ctx
    |> mes("[Iwado]")
    |> mes(
      "Oh! You have all the items necessary to make 1 Singing Flower!! Good, good! With all my pride as a monster tamer, I will make it for you right away."
    )
    |> next()
    |> mes("[Iwado]")
    |> mes("Got to...")
    |> mes("Twist this...")
    |> mes("Just right...")
    |> next()
    |> mes("^3355FF*Crumble crumble scratch scratch*^000000")
    |> next()
    |> mes("[Iwado]")
    |> mes("Okay. All done!")
    |> mes("Please take it for the")
    |> mes("cute monster you")
    |> mes("are raising.")
    |> mes("Singing Flower!")
    |> delitem(707, 1)
    |> give_item(629, 1)
    |> close()
  end

  @spec singing_flower_recipe(Ctx.t()) :: Ctx.t()
  defp singing_flower_recipe(ctx) do
    ctx
    |> mes("[Iwado]")
    |> mes("For the monster owner")
    |> mes("that loves to use Singing Flower...")
    |> mes("I provide a way to make")
    |> mes("1 Singing Flower!")
    |> next()
    |> mes("[Iwado]")
    |> mes("If you bring me")
    |> mes("^3355FF1 Singing Plant ^000000,")
    |> mes("With all my pride as a monster tamer, I will make one for you right away!")
    |> close()
  end

  @spec wild_flower(Ctx.t()) :: Ctx.t()
  defp wild_flower(ctx) do
    ctx =
      ctx
      |> mes("[Iwado]")
      |> mes(
        "This is a flower that is far beyond what humans can gaze at! Its name? ^3355FFWild Flower^000000 !! A troublesome design, but perfect for monsters!"
      )
      |> next()

    if count_item(ctx, 2207) > 0 and count_item(ctx, 705) > 0 do
      brew_wild_flower(ctx)
    else
      wild_flower_recipe(ctx)
    end
  end

  @spec brew_wild_flower(Ctx.t()) :: Ctx.t()
  defp brew_wild_flower(ctx) do
    ctx
    |> mes("[Iwado]")
    |> mes(
      "Oh! You have all the items necessary to make 1 Wild Flower! Good! Good! With all my pride as a monster tamer, I will make one for you right away."
    )
    |> next()
    |> mes("[IWado]")
    |> mes("Got to twist this...")
    |> mes("Just right...")
    |> next()
    |> mes("^3355FF*Crumble crumble rip rip*^000000")
    |> next()
    |> mes("[Iwado]")
    |> mes("Okay. All done!")
    |> mes("Please take it for the")
    |> mes("cute monsters you")
    |> mes("are raising.")
    |> mes("Wild Flower!")
    |> delitem(2207, 1)
    |> delitem(705, 1)
    |> give_item(10009, 1)
    |> close()
  end

  @spec wild_flower_recipe(Ctx.t()) :: Ctx.t()
  defp wild_flower_recipe(ctx) do
    ctx
    |> mes("[Iwado]")
    |> mes("For the monster owner")
    |> mes("that loves to use Wild Flower...")
    |> mes("I provide a way to make")
    |> mes("1 Wild Flower!")
    |> next()
    |> mes("[Iwado]")
    |> mes("^3355FF1 Fancy Flower^000000 and")
    |> mes("^3355FF1 Clover^000000")
    |> mes(
      "is all I need! If you bring those to me, I will make one for you with all my pride as a monster tamer!"
    )
    |> close()
  end

  @spec undecided(Ctx.t()) :: Ctx.t()
  defp undecided(ctx) do
    ctx
    |> mes("[Iwado]")
    |> mes("Ah...!")
    |> mes("You must have not decided which Monster you want to raise.")
    |> next()
    |> mes("[Iwado]")
    |> mes(
      "Definitely not a decision to be made carelessly! Your pet monster will accompany you throughout your life. Please take your time and return when you have decided."
    )
    |> close()
  end
end
