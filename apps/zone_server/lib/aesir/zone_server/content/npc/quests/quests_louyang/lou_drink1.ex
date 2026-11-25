defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsLouyang.LouDrink1 do
  @moduledoc """
  Bai Long's drink bottle provides a target for the poison quest.

  ## Behavior

  - Poisons the drink or replaces it with mucus at the relevant quest stage.
  - Advances the quest and consumes the required items.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - Lupus
    - SinSloth
    - L0ne_W0lf
    - Paradox924X
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lou_in01",
        x: 107,
        y: 163,
        dir: 0,
        sprite: 111,
        name: " ",
        scope: :shared,
        unique_name: " #lou_drink1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :ch_poison, 0) do
      12 ->
        poison_drink(ctx)

      13 ->
        ctx
        |> mes("^3355FFIt would be smart to get out of this place as soon as you can.^000000")
        |> close()

      16 ->
        replace_drink(ctx)

      _ ->
        ctx
        |> mes(
          "^3355FFYou found a drink bottle. It's fancy enough that the only possible owner could be Bai Long, lord of Luoyang.^000000"
        )
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp poison_drink(ctx) do
    ctx
    |> mes(
      "^3355FFYou found a drink bottle that's possibly owned by Bai Long, lord of Luoyang.^00000"
    )
    |> next()
    |> mes("^3355FFYou put the deadly poison into the bottle.^000000")
    |> delitem(678, 1)
    |> set_char_var(:ch_poison, 13)
    |> changequest(11076, 11077)
    |> close()
  end

  defp replace_drink(ctx) do
    if count_item(ctx, 938) > 0 and count_item(ctx, 713) > 0 do
      ctx
      |> mes(
        "^3355FFYou take the drink bottle and replace it with a bottle filled with Sticky Mucus. Hopefully Bai Long won't notice!^000000"
      )
      |> delitem(938, 1)
      |> delitem(713, 1)
      |> set_char_var(:ch_poison, 17)
      |> changequest(11079, 11080)
      |> close()
    else
      ctx
      |> mes(
        "^3355FFIt seems that you need switch Bai Long's drinking bottle with something else. Just taking the drink bottle would arouse suspicion.^000000"
      )
      |> next()
      |> mes(
        "^3355FFMaybe if you found some kind of empty bottle and filled it with something, like Sticky Mucus...^000000"
      )
      |> close()
    end
  end
end
