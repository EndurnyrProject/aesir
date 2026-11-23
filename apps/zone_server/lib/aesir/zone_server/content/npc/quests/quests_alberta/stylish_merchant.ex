defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.StylishMerchant do
  @moduledoc """
  Zic crafts accessories for visitors to Alberta.

  ## Behavior

  - Crafts the first available accessory when the player carries its materials.
  - Otherwise describes the materials needed for each accessory.

  ## Credits

  - Original from rAthena, authors and contributors:
    - kobra_k88
    - Lupus
    - Evera
    - DZeroX
    - L0ne_W0lf
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "alberta",
        x: 120,
        y: 53,
        dir: 1,
        sprite: 51,
        name: "Stylish Merchant",
        scope: :shared,
        unique_name: "Stylish Merchant#new30"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      count_item(ctx, 10007) > 0 and count_item(ctx, 968) > 49 ->
        ctx
        |> mes("[Zic]")
        |> mes(
          "I know I know, you just want to get a Bao Bao of your own. But I can't concentrate on my work if you keep rushing me like this."
        )
        |> craft_accessory()
        |> delitem(10007, 1)
        |> delitem(968, 50)
        |> mes("[Zic]")
        |> mes("Phew!")
        |> mes("There you go~!")
        |> mes("Now make good use of it!!")
        |> give_item(5042, 1)
        |> close()

      count_item(ctx, 5041) > 0 and count_item(ctx, 999) > 9 ->
        ctx
        |> mes("[Zic]")
        |> mes(
          "Alright alright! Gosh, your Crescent Hairpin will be ready in a bit, but I can't concentrate my work if you keep rushing me like this!"
        )
        |> craft_accessory()
        |> delitem(5041, 1)
        |> delitem(999, 10)
        |> mes("[Zic]")
        |> mes("Phew!")
        |> mes("It's done~!")
        |> mes("Now wear it and")
        |> mes("look pretty or")
        |> mes("something, yeah?")
        |> give_item(5048, 1)
        |> close()

      count_item(ctx, 2271) > 0 and count_item(ctx, 975) > 0 ->
        ctx
        |> mes("[Zic]")
        |> mes(
          "Yeah yeah, you came for your Fashionable Glasses. Just don't rush me, or I won't be able to concentrate on my work, alright?"
        )
        |> craft_accessory()
        |> delitem(2271, 1)
        |> delitem(975, 1)
        |> mes("[Zic]")
        |> mes("Phew, it's done!")
        |> mes("Now go wear these and look, well, as fashionable as these glasses, I guess.")
        |> give_item(5047, 1)
        |> close()

      count_item(ctx, 7013) > 1199 ->
        ctx
        |> mes("[Zic]")
        |> mes(
          "Okay okay, you want your Heart hairpin, I'm working on it. Yeesh, I can't concentrate at all if you try to rush me, you know?"
        )
        |> craft_accessory()
        |> delitem(7013, 1200)
        |> mes("[Zic]")
        |> mes("Phew~!")
        |> mes("Finally, it's done!")
        |> mes("Make me happy and")
        |> mes("wear it with pride~")
        |> give_item(5041, 1)
        |> close()

      true ->
        {ctx, choice} =
          ctx
          |> mes("[Zic]")
          |> mes("Yay, this cool")
          |> mes("breeze is great!")
          |> mes("I love the sea!")
          |> next()
          |> mes("[Zic]")
          |> mes("...Hm?")
          |> mes("Awww man. Can't you tell I'm on vacation? All I wanted was some peaceful rest.")
          |> next()
          |> mes("[Zic]")
          |> mes(
            "Okay okay, you win. Once again, my reputation as a master craftsman precedes me."
          )
          |> next()
          |> mes("[Zic]")
          |> mes("Let me know what item you're interested in, and maybe I'll make it for you...")
          |> next()
          |> select(["Bao Bao", "Cresent Hairpin", "Fashionable Glasses", "Heart Hairpin"])

        case choice do
          1 ->
            ctx
            |> mes("[Zic]")
            |> mes("Sooo...")
            |> mes("You want me to make you a Bao Bao, huh? Alright, alright...")
            |> next()
            |> mes("[Zic]")
            |> mes("Let's see, I'll need...")
            |> mes("1 ^0000FFSilk Ribbon^000000")
            |> mes("50 ^0000FFHeroic Emblem^000000")
            |> mes("...Did you know this already?")
            |> close()

          2 ->
            ctx
            |> mes("[Zic]")
            |> mes(
              "So you want a Crescent Hairpin, huh? Man, I guess these things are pretty high in demand."
            )
            |> next()
            |> mes("[Zic]")
            |> mes("Okay, I'll need...")
            |> mes("1 ^0000FFHeart Hairpin^000000")
            |> mes("10 ^0000FFSteel^000000")
            |> mes("...Did you know this already?")
            |> close()

          3 ->
            ctx
            |> mes("[Zic]")
            |> mes(
              "Weird. How'd you know I make Fashionable Glasses? I guess I must be more famous that I thought."
            )
            |> next()
            |> mes("[Zic]")
            |> mes("I need to have...")
            |> mes("1 ^0000FFJack be Dandy^000000")
            |> mes("1 ^0000FFScarlet Dyestuffs^000000")
            |> mes("...Did you know this already?")
            |> close()

          4 ->
            ctx
            |> mes("[Zic]")
            |> mes(
              "You want a heart hairpin, eh? Okay, I think I can work something out for you..."
            )
            |> next()
            |> mes("[Zic]")
            |> mes("Just gimmie...")
            |> mes("1200 ^0000FFCoral Reef^000000.")
            |> mes("...Did you know this already?")
            |> close()

          _ ->
            ctx
        end
    end
  end

  defp craft_accessory(ctx) do
    ctx
    |> next()
    |> mes("^3355FF*Thud! Thud!*")
    |> mes("*Ah! Kek! Smash!*")
    |> mes("*Boom Boom!*^000000")
    |> next()
  end
end
