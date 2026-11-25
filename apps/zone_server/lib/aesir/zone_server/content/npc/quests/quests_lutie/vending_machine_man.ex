defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLutie.VendingMachineMan do
  @moduledoc """
  Titicupe, the Toy Factory manager who invented the snowman vending machine.

  ## Behavior

  - Brags about the vending machine and how it works.
  - Lists the materials the machine needs for each headgear.

  ## Credits

  - Original from rAthena, authors and Contributors
    - TonyMan
    - Samuray22
    - Lupus
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "xmas",
        x: 117,
        y: 295,
        dir: 4,
        sprite: 704,
        name: "Vending Machine Man",
        scope: :shared
      }
    ]

  @recipes %{
    1 => [
      "Raccoon Hat?",
      "1 Kitty Band",
      "20 Dragon Scale",
      "200 Tough Scalelike Stem",
      "300 Sea-otter Fur"
    ],
    2 => ["Spore Hat?", "850 Poison Spore", "300 Burnt Tree", "1 Tongue"],
    3 => ["Wonder Nutshell?", "1 Nut Shell", "500 Wing of Dragonfly"],
    4 => ["Rainbow Eggshell?", "1 Egg Shell", "1 Cobaltblue Dyestuffs", "50 Claw of Desert Wolf"],
    5 => ["Blush?!", "You!", "You know something...", "Heh heh~ Anyway", "100 Alice's Apron"],
    6 => [
      "Chef Hat?",
      "120 Piece of Cake",
      "1 White Dyestuffs",
      "330 Feather",
      "450 Dragon Scale"
    ],
    7 => ["Candle?", "1 Bomb Wick", "50 Matchstick", "100 Royal Jelly"],
    8 => [
      "Cake Hat?",
      "10 Candy",
      "5 Candy Cane",
      "15 Well-baked Cookie",
      "20 Piece Of Cake",
      "10 Steel"
    ],
    9 => ["Ask me anytime. Those kinds of questions are no problem for geniuses like me!"]
  }

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Titicupe]")
      |> mes("Hmm...?")
      |> mes(
        "I, Titicupe, esteemed manager of the Toy Factory and genius inventor, has done it again! I've just created the world's most sophisticated vending machine!"
      )
      |> next()
      |> select([
        "Talk to him about the Vending Machine",
        "Items in the Vending Machine",
        "Stop talking"
      ])

    case choice do
      1 -> about_machine(ctx)
      2 -> recipes(ctx)
      3 -> stop_talking(ctx)
      _ -> ctx
    end
  end

  defp about_machine(ctx) do
    ctx
    |> mes("[Titicupe]")
    |> mes(
      "Can you see the little snowman to the left side of me? Can you? If you look at his mouth closely, you'll see that it's been built quite largely. You might say, a bit too large for normal purposes..."
    )
    |> next()
    |> mes("[Titicupe]")
    |> mes(
      "You see, that snowman is actually an amazing vending machine that I invented out of my blood, sweat, tears and snow."
    )
    |> next()
    |> mes("[Titicupe]")
    |> mes(
      "You can put all sorts of things inside its mouth, and if you insert the right items, you'll get some hats in return..."
    )
    |> next()
    |> mes("[Titicupe]")
    |> mes("Fashionable hats that you've always dreamed of wearing...! Bwahahahaha~!")
    |> next()
    |> mes("[Titicupe]")
    |> mes("Oh, this creation of mine is so magnificent!")
    |> emotion(:chupchup)
    |> next()
    |> mes("[Titicupe]")
    |> mes("And the headgears--! I... I can't contain myself!")
    |> next()
    |> mes(
      "^3355FFToy factory manager Titicupe jumps and convulses with joy. Clearly he's insane, but it may be possible that he may be brilliant.^000000"
    )
    |> emotion(:surprise)
    |> close()
  end

  defp recipes(ctx) do
    {ctx, headgear} =
      ctx
      |> mes("[Titicupe]")
      |> mes(
        "Oh right! You need to know what kind of items to put into the Vending Machine to get what you want, yes? Go ahead... Ask me~"
      )
      |> emotion(:aha)
      |> next()
      |> select([
        "Raccoon Hat",
        "Spore Hat",
        "Wonder Nutshell",
        "Ranbow Eggshell",
        "Blush",
        "Chef Hat",
        "Candle",
        "Cake Hat",
        "End Conversation"
      ])

    case Map.fetch(@recipes, headgear) do
      {:ok, lines} ->
        ["[Titicupe]" | lines]
        |> Enum.reduce(ctx, &mes(&2, &1))
        |> next()
        |> mes("[Titicupe]")
        |> mes("So happy!!")
        |> mes("I'm a genius~!")
        |> mes("Ho ho ho")
        |> mes("Ho ho ho ho!")
        |> close()

      :error ->
        ctx
    end
  end

  defp stop_talking(ctx) do
    ctx
    |> mes("[Titicupe]")
    |> mes("Sometimes, I can't believe how magnificent this invention of mine is...!")
    |> next()
    |> mes("[Titicupe]")
    |> mes("I...")
    |> mes("I love you")
    |> mes("Mister Snowman")
    |> mes("Vending Machine.")
    |> emotion(:chupchup)
    |> next()
    |> mes(
      "^3355FFToy factory manager Titicupe begins to jump around and emit screams of unbridled ecstacy. At this point, it's not difficult to doubt his sanity, as well as his genius."
    )
    |> close()
  end
end
