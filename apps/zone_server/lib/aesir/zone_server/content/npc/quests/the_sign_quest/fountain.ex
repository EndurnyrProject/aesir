defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Fountain do
  @moduledoc """
  Offers fountain water to drink or bottle as the quest progresses.

  ## Behavior

  - Drinking harms the player; bottling requires an empty bottle and inventory space.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_sign01",
        x: 46,
        y: 56,
        dir: 0,
        sprite: 111,
        name: "Fountain",
        scope: :shared,
        unique_name: "Fountain#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])

    if get_char_var(ctx, :sign_q, 0) < 118 do
      {ctx, choice} =
        ctx
        |> mes("^3355FFThe water in this")
        |> mes("fountain looks clean")
        |> mes("enough to drink...^000000")
        |> next()
        |> select(["Drink.", "Don't Drink."])

      case choice do
        1 -> ctx |> mes("...") |> close2() |> percent_heal(hp: -100, sp: 0)
        2 -> ctx |> mes("...") |> close()
        _ -> ctx
      end
    else
      {ctx, choice} =
        ctx
        |> mes("^3355FFThe water in this")
        |> mes("fountain looks clean")
        |> mes("enough to be bottled...^000000")
        |> next()
        |> select(["Bottle the water.", "Don't bottle the water."])

      case choice do
        1 -> bottle_water(ctx)
        2 -> ctx |> mes("...") |> close()
        _ -> ctx
      end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp bottle_water(ctx) do
    cond do
      checkweight(ctx, [{1201, 1}]) == 0 ->
        ctx
        |> mes("^3355FFUnfortunately, it")
        |> mes("looks like you don't")
        |> mes("have enough inventory")
        |> mes("space to carry any more items...^000000")
        |> close()

      count_item(ctx, 713) > 0 ->
        ctx |> delitem(713, 1) |> give_item(12020, 1) |> close()

      true ->
        ctx
        |> mes("^3355FFUnfortunately, it")
        |> mes("looks like you don't")
        |> mes("have any Empty Bottles")
        |> mes("to carry any of this water... ^000000")
        |> close()
    end
  end
end
