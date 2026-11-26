defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsPayon.MysticLady do
  @moduledoc """
  A Payon craftswoman who sells her family's Ear Muffs for materials and zeny.

  ## Behavior

  - Ear Muffs cost 1 Cursed Ruby, 200 Feathers, 1 Headset and 5,000 zeny.
  - Without every material and the zeny she refuses and takes nothing.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - Lupus
    - Silent
    - Samuray22
    - L0ne_W0lf
    - JohnnyPlayy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{map: "payon_in01", x: 18, y: 10, dir: 4, sprite: 76, name: "Mystic Lady", scope: :shared}
    ]

  @speaker "[Mystic Lady]"

  @cursed_ruby 724
  @feather 949
  @headset 5001
  @ear_muffs 2283
  @price 5000

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes(
        "My family has produced and sold the special Winter product ^3355FFEar Muffs^000000 for many years. We just moved here, but the weather is always warm so we can hardly make a living."
      )
      |> next()
      |> mes(@speaker)
      |> mes(
        "If you plan to travel to colder regions, I suggest that you bring some ^3355FFEar Muffs^000000..."
      )
      |> emotion(:think)
      |> next()
      |> mes(@speaker)
      |> mes(
        "Ear Muffs are my family's specialty, and we provide it to customers who have ^FF33551 Cursed Ruby^000000, ^3311AA1 Headset,^000000 ^3355FF 200 Feathers^000000 and ^DDDD005000 Zeny^000000."
      )
      |> emotion(:think)
      |> next()
      |> select(["Oh Yeah? That sounds good.", "No thank you, Ma'am."])

    case choice do
      1 ->
        if can_afford?(ctx), do: sell_ear_muffs(ctx), else: refuse(ctx)

      2 ->
        ctx
        |> mes(@speaker)
        |> mes("That's fine.")
        |> mes("I believe we")
        |> mes("will meet again.")
        |> mes("...One of these days.")
        |> emotion(:think)
        |> close()

      _ ->
        ctx
    end
  end

  defp can_afford?(ctx) do
    count_item(ctx, @cursed_ruby) >= 1 and count_item(ctx, @feather) >= 200 and
      count_item(ctx, @headset) >= 1 and zeny(ctx) >= @price
  end

  defp sell_ear_muffs(ctx) do
    ctx
    |> mes(@speaker)
    |> delitem(@cursed_ruby, 1)
    |> delitem(@feather, 200)
    |> delitem(@headset, 1)
    |> pay_zeny(@price)
    |> mes("Here, I will give you this pre-made one.")
    |> give_item(@ear_muffs, 1)
    |> next()
    |> mes(@speaker)
    |> mes(
      "Thank you for buying our product. You won't regret purchasing our Ear Muffs: Satisfaction guaranteed~"
    )
    |> emotion(:think)
    |> close()
  end

  defp refuse(ctx) do
    ctx
    |> mes(@speaker)
    |> mes("Oh dear...")
    |> mes(
      "You don't have enough money or items. Unfortunately, we can't give any discounts. Please understand that we have to make a living..."
    )
    |> emotion(:think)
    |> close()
  end
end
