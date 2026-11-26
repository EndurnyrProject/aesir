defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.QuestsPayon.YoungMan do
  @moduledoc """
  A secretive Payon craftsman who makes the Helm of Angel and the Deviruchi Cap from
  gathered materials.

  ## Behavior

  - Helm of Angel: takes 1 Helm (with slot), 1 Angelic Chain and 5 Fang of Garm.
  - Deviruchi Cap: takes 600 Little Evil Horn and 40 Talon of Griffon.
  - Materials are taken before the dialog closes and the headgear is given after it closes.
  - Missing materials end the talk with a warning and take nothing.

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
  - Added the renewal and pre-renewal `Young man#1` duplicate placements, which the importer
    did not record on the floating body
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Young man", scope: :shared, unique_name: "Young man#12"},
      %{
        map: "payon_in01",
        x: 46,
        y: 21,
        dir: 4,
        sprite: 89,
        name: "Young man",
        scope: :renewal,
        unique_name: "Young man#1"
      },
      %{
        map: "payon_in01",
        x: 56,
        y: 12,
        dir: 7,
        sprite: 89,
        name: "Young man",
        scope: :pre_renewal,
        unique_name: "Young man#1"
      }
    ]

  @speaker "[Young man]"

  @helm 2229
  @angelic_chain 2254
  @fang_of_garm 7036
  @helm_of_angel 5025

  @little_evil_horn 1038
  @talon_of_griffin 7048
  @deviruchi_cap 5038

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes("...What is it?")
      |> next()
      |> select(["Can you make me a special item?", "Hey."])

    case choice do
      1 -> special_item(ctx)
      2 -> ctx |> mes(@speaker) |> mes("Hm.") |> mes("Take care.") |> close()
      _ -> ctx
    end
  end

  defp special_item(ctx) do
    {ctx, choice} =
      ctx
      |> mes(@speaker)
      |> mes(
        "Huh? So you already know what I specialize in, eh? I suppose there's no need for the usual secrecy. Tell me what you want."
      )
      |> next()
      |> select(["Helm of Angel.", "Deviruchi Cap.", "I will come next time."])

    case choice do
      1 ->
        ctx
        |> mes(@speaker)
        |> mes("1 Helm (with slot).")
        |> mes("1 Angel Wing.")
        |> mes("5 Fang of Garm.")
        |> offer(&make_helm_of_angel/1)

      2 ->
        ctx
        |> mes(@speaker)
        |> mes("600 Little Evil Horn.")
        |> mes("40 Talon of Griffon.")
        |> offer(&make_deviruchi_cap/1)

      3 ->
        ctx
        |> mes(@speaker)
        |> mes("Hm. Alright.")
        |> mes("Then we shall meet again.")
        |> close()

      _ ->
        ctx
    end
  end

  defp offer(ctx, make) do
    {ctx, choice} =
      ctx
      |> mes("That's all I require.")
      |> next()
      |> mes(@speaker)
      |> mes(
        "Wait! Just so you know, I don't care if the items in your inventory have been upgraded, or have cards attached."
      )
      |> next()
      |> mes(@speaker)
      |> mes(
        "I mean, any cards or upgrades in the items I will use to make something for you will be lost once I make the item. So be careful when you hand stuff over to me."
      )
      |> next()
      |> mes(@speaker)
      |> mes("Did you gather the items? Then hand them over.")
      |> next()
      |> select(["Give him the items.", "Don't give him the items."])

    case choice do
      1 -> make.(ctx)
      2 -> ctx |> mes(@speaker) |> mes("Do as you wish...") |> close()
      _ -> ctx
    end
  end

  defp make_helm_of_angel(ctx) do
    if count_item(ctx, @helm) >= 1 and count_item(ctx, @angelic_chain) >= 1 and
         count_item(ctx, @fang_of_garm) >= 5 do
      ctx
      |> mes(@speaker)
      |> mes(".....Hm.")
      |> mes("Fine, here's your Helm of Angel. Take it.")
      |> delitem(@helm, 1)
      |> delitem(@angelic_chain, 1)
      |> delitem(@fang_of_garm, 5)
      |> close2()
      |> give_item(@helm_of_angel, 1)
    else
      ctx
      |> mes(@speaker)
      |> mes("...The number of items is not right. You better double check.")
      |> close()
    end
  end

  defp make_deviruchi_cap(ctx) do
    if count_item(ctx, @little_evil_horn) >= 600 and count_item(ctx, @talon_of_griffin) >= 40 do
      ctx
      |> mes(@speaker)
      |> mes(".....Hm. Here's your Deviruchi Hat. Please take it.")
      |> delitem(@little_evil_horn, 600)
      |> delitem(@talon_of_griffin, 40)
      |> close2()
      |> give_item(@deviruchi_cap, 1)
    else
      ctx
      |> mes(@speaker)
      |> mes("...The number of items isn't right. You better double check.")
      |> close()
    end
  end
end
