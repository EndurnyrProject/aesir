defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsAlberta.Cherokee do
  @moduledoc """
  Cherokee collects animal horns.

  ## Behavior

  - Trades an Antler for twenty Evil Horns.

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
      %{map: "alberta_in", x: 122, y: 53, dir: 4, sprite: 47, name: "Cherokee", scope: :shared}
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("[Cherokee]")
      |> mes("Hey there~!")
      |> next()
      |> mes("[Cherokee]")
      |> mes(
        "What do you think about animal horns? Oh man, I think they're great! Don't you? I love animal horns so much I became a ^3355FFHorn Collector^000000."
      )
      |> next()
      |> mes("[Cherokee]")
      |> mes(
        "I mean, there's so many things you can do with horns. You can wear them on your head, you can wear them on, um... your house? All sorts of things!"
      )
      |> next()
      |> mes("[Cherokee]")
      |> mes(
        "I've collected almost every sort of horn except for one kind, and that's ^FF3355Evil Horn^000000. Some people say Evil Horn doesn't even come from an animal, but from a demon. But even so, I still want it."
      )
      |> next()
      |> mes("[Cherokee]")
      |> mes("Do you...")
      |> mes("Do you have ^FF3355Evil Horn^000000?")
      |> mes(
        "If you offer me 20 Evil Horns, I will give you an ^3355FFAntler^000000 from my precious collection. So, deal?"
      )
      |> next()
      |> select(["Okay, let's deal.", "Shut up, Dumbo."])

    case choice do
      1 ->
        if count_item(ctx, 923) > 19 do
          ctx
          |> delitem(923, 20)
          |> mes("[Cherokee]")
          |> mes("Whoah~! This is the first time I've ever seen a real ^FF3355Evil Horn^000000!!")
          |> mes("Thank you! Here, this is my Antler for you!")
          |> give_item(2284, 1)
          |> next()
          |> mes("[Cherokee]")
          |> mes(
            "With your great help, I can make my wish come true this time. Finally, I'll be recognized as a serious horn collector. I appreciate this~!"
          )
          |> close()
        else
          ctx
          |> mes("[Cherokee]")
          |> mes("Hmm...")
          |> mes(
            "You don't seem to have enough. I need ^FF335520 Evil Horns^000000 for my collection."
          )
          |> close()
        end

      2 ->
        ctx
        |> mes("[Cherokee]")
        |> mes(
          "Well that's fine. Although you're a rude prick, I will forgive you. We'll probably speak again..."
        )
        |> close()

      _ ->
        ctx
    end
  end
end
