defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Monstertamers.MonstertamerIzlude do
  @moduledoc """
  Izlude's monster tamer Shogo, who brews the Book of Devil, No Recipient and Orc Trophy
  pet items from their component items.

  The script has no placement of its own; the renewal and pre-renewal Izlude Monster Tamer
  NPCs duplicate it.

  ## Behavior

  - Explains the three recipes: Book of Devil (1 Old Magic Book and 2 Horrendous Mouth),
    No Recipient (1 Old Portrait), Orc Trophy (1 Chivalry Emblem and 1 Scorpion Tail)
  - With the components in hand, consumes them and hands over the pet item: Book of Devil
    (642), No Recipient (636) or Orc Trophy (635)
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
        map: "izlude_in",
        x: 55,
        y: 105,
        dir: 4,
        sprite: 125,
        name: "Monster Tamer",
        scope: :renewal,
        unique_name: "Monster Tamer#izu"
      },
      %{
        map: "izlude_in",
        x: 129,
        y: 64,
        dir: 4,
        sprite: 125,
        name: "Monster Tamer",
        scope: :pre_renewal,
        unique_name: "Monster Tamer#izu"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Shogo]")
      |> mes("Are you pre-occupied with")
      |> mes("gathering items for monsters")
      |> mes("and want a break? ")
      |> mes("We will gather items")
      |> mes("for your Cute Pets.")
      |> next()
      |> select([
        "^3355FF' Monster Taming '^000000?",
        "Order ^3355FF' Book of Devil '^000000",
        "Order ^3355FF' No Recipient '^000000",
        "Order ^3355FF' Orc Trophy '^000000",
        "Cancel"
      ])

    case choice do
      1 -> explain_recipes(ctx)
      2 -> book_of_devil(ctx)
      3 -> no_recipient(ctx)
      4 -> orc_trophy(ctx)
      5 -> undecided(ctx)
      _ -> ctx
    end
  end

  @spec explain_recipes(Ctx.t()) :: Ctx.t()
  defp explain_recipes(ctx) do
    ctx
    |> mes("[Shogo]")
    |> mes(
      "The monster taming items are necessary to communicate with the monster of your choice! We Monster Tamer guild members have a very reasonable offer..."
    )
    |> next()
    |> mes("[Shogo]")
    |> mes(
      "We provide a system that allows you to get your hands on these cool items with less of the hassle!"
    )
    |> mes("Book of Devil!")
    |> mes("No Recipient!")
    |> mes("Orc Trophy!")
    |> next()
    |> mes("[Shogo]")
    |> mes("For 1 Book of Devil, you can exchange:")
    |> mes("^3355FF1 Old Magic Book^000000")
    |> mes("^3355FF2 Horrendous Mouth^000000.")
    |> next()
    |> mes("[Shogo]")
    |> mes("For 1 No Recipient, you can exchange ^3355FF1 Old Portrait^000000.")
    |> next()
    |> mes("[Shogo]")
    |> mes("Lastly, you can exchange")
    |> mes("^3355FF1 Chivalry Emblem^000000 and")
    |> mes("^3355FF1 Scorpion Tail^000000")
    |> mes("for 1 Orc Trophy.")
    |> mes("Try these fantastic items!")
    |> close()
  end

  @spec book_of_devil(Ctx.t()) :: Ctx.t()
  defp book_of_devil(ctx) do
    ctx =
      ctx
      |> mes("[Shogo]")
      |> mes(
        "This is an item far beyond what humans can read! Its name? ^3355FFBook of Devil^000000! A very mysterious item that can supposedly summon demons..."
      )
      |> next()

    if count_item(ctx, 1006) > 0 and count_item(ctx, 958) > 1 do
      ctx
      |> mes("[Shogo]")
      |> mes(
        "Oh! You have all the items necessary to make 1 Book of Devil! Good, good! With all my pride as a monster tamer, I will make one for you right away."
      )
      |> next()
      |> mes("[Shogo]")
      |> mes("Let's see...")
      |> mes("Hmm, this is going to be hard.")
      |> next()
      |> mes("^3355FF*Knock knock scrape scrape*^000000")
      |> next()
      |> mes("[Shogo]")
      |> mes("Okay. All done.")
      |> mes("Please take it for")
      |> mes("the cute monster you")
      |> mes("are raising.")
      |> mes("Book of Devil!")
      |> delitem(958, 2)
      |> delitem(1006, 1)
      |> give_item(642, 1)
      |> close()
    else
      ctx
      |> mes("[Shogo]")
      |> mes(
        "For the owner that wishes to raise a monster that can be summoned using the Book of Devil, we provide a way to create 1 Book of Devil!"
      )
      |> next()
      |> mes("[Shogo]")
      |> mes("Just bring me...")
      |> mes("^3355FF1 Old Magicbook^000000 and")
      |> mes("^3355FF2 Horrendous Mouth^000000!")
      |> mes(
        "If you bring me these items, with all my pride as a monster tamer, I will make it for you!"
      )
      |> close()
    end
  end

  @spec no_recipient(Ctx.t()) :: Ctx.t()
  defp no_recipient(ctx) do
    ctx =
      ctx
      |> mes("[Shogo]")
      |> mes(
        "This is an item which expresses feelings beyond what a human can feel. Its name? ^3355FFNo Recipient^000000! Who sent this letter, and who was supposed to receive it?"
      )
      |> next()

    if count_item(ctx, 7014) > 0 do
      ctx
      |> mes("[Shogo]")
      |> mes(
        "Oh! You have all the items necessary to make No Recipient! Good, good! With all my pride as a monster tamer, I will make one for you right away."
      )
      |> next()
      |> mes("[Shogo]")
      |> mes("Got to fold this Old Portrait just right...")
      |> next()
      |> mes("^3355FF*Scrape scrape brush brush*^000000")
      |> next()
      |> mes("[Shogo]")
      |> mes("Okay. All done.")
      |> mes("Please take this item")
      |> mes("for the cute monster")
      |> mes("you are raising.")
      |> mes("No Recipient!")
      |> delitem(7014, 1)
      |> give_item(636, 1)
      |> close()
    else
      ctx
      |> mes("[Shogo]")
      |> mes(
        "For the monster owner that is fond of No Recipient, we provide a way to create to special item!"
      )
      |> next()
      |> mes("[Shogo]")
      |> mes("Just bring me...")
      |> mes("^3355FF1 Old Portrait^000000!")
      |> mes(
        "If you bring this to me, with all my pride as a monster tamer, I will make it for you!"
      )
      |> close()
    end
  end

  @spec orc_trophy(Ctx.t()) :: Ctx.t()
  defp orc_trophy(ctx) do
    ctx =
      ctx
      |> mes("[Shogo]")
      |> mes("This is an item far beyond the pride of humans!")
      |> mes("Its name?")
      |> mes("^3355FFOrc Trophy^000000!")
      |> next()

    if count_item(ctx, 1004) > 0 and count_item(ctx, 904) > 0 do
      ctx
      |> mes("[Shogo]")
      |> mes(
        "Oh! You have all the items necessary to make an Orc Trophy! Good, good! With all my pride as a monster tamer, let me make one for you right away!"
      )
      |> next()
      |> mes("[Shogo]")
      |> mes("Got to...")
      |> mes("Fit this Scorpion Tail...")
      |> mes("Just right...")
      |> next()
      |> mes("^3355FF*Clang clang Boong*^000000")
      |> next()
      |> mes("[Shogo]")
      |> mes("Okay. All done.")
      |> mes("Please take this for")
      |> mes("the cute monster")
      |> mes("you are raising...")
      |> mes("Orc Trophy!")
      |> delitem(904, 1)
      |> delitem(1004, 1)
      |> give_item(635, 1)
      |> close()
    else
      ctx
      |> mes("[Shogo]")
      |> mes("For the monster owner")
      |> mes("who is fond of Horror of Tribe...")
      |> mes("One way to make Horror of Tribe !")
      |> mes("^3355FF 1 Chivalry Emblem^000000!")
      |> mes("^3355FF 1 Scorpion Tail^000000!")
      |> next()
      |> mes("[Shogo]")
      |> mes("If you bring these items to me,")
      |> mes("with all my pride as a monster")
      |> mes("tamer, I will make it for you!")
      |> close()
    end
  end

  @spec undecided(Ctx.t()) :: Ctx.t()
  defp undecided(ctx) do
    ctx
    |> mes("[Shogo]")
    |> mes("Ah...!")
    |> mes("You must have not decided which Monster you want to raise.")
    |> next()
    |> mes("[Shogo]")
    |> mes(
      "Definitely not a decision to be made carelessly! Your pet monster will accompany you throughout your life. Please take your time and return when you have decided."
    )
    |> close()
  end
end
