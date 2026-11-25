defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.BubblingSwamp do
  @moduledoc """
  A bubbling swamp holds herbs needed for an adhesive.

  ## Behavior

  - Advances the search for Mikhail and yields herbs during the adhesive quest.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  - Corrected `mos_swan == 11 && mos_swan == 12` to match either quest stage.
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_dun03",
        x: 153,
        y: 90,
        dir: 3,
        sprite: 844,
        name: "Bubbling Swamp",
        scope: :shared,
        unique_name: "Bubbling Swamp#mos1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    if max_weight(ctx) - weight(ctx) < 2000 do
      ctx |> mes("- Your bag is very heavy today -") |> close()
    else
      inspect_swamp(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp inspect_swamp(ctx) do
    stage = get_char_var(ctx, :mos_swan, 0)

    cond do
      stage == 10 ->
        ctx
        |> mes("- You feel sticky just looking at this swamp. -")
        |> next()
        |> mes("- Gas bubbles are rising. The atmosphere here is pretty scary -")
        |> next()
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes(
          "I don't see any traces of Mikhail. I think I should go back and check his house one more time."
        )
        |> set_char_var(:mos_swan, 11)
        |> changequest(18063, 18064)
        |> close()

      stage in [11, 12] ->
        ctx
        |> mes("- You can see a small muddy swamp -")
        |> next()
        |> mes("- Gas bubbles are rising. The atmosphere here is pretty scary -")
        |> close()

      stage > 12 and stage < 23 ->
        collect_herb(ctx)

      true ->
        ctx
        |> mes("- You can see a small swamp which seems very muddy. -")
        |> next()
        |> mes("- Gas bubbles are rising. The atmosphere here is pretty scary -")
        |> close()
    end
  end

  defp collect_herb(ctx) do
    ctx =
      ctx
      |> mes("- You feel sticky just looking at the swamp. -")
      |> next()
      |> mes("- Gas bubbles are rising. The atmosphere here is pretty scary -")
      |> next()
      |> mes("- You stretch out to find sticky herbs. -")
      |> next()

    if Enum.random(1..10) < 6 do
      ctx =
        ctx
        |> mes("- You have pricked your finger on a Sticky Herb. -")
        |> give_item(7763, 1)

      ctx = set_char_var(ctx, :mos_swan, get_char_var(ctx, :mos_swan, 0) + 1)

      ctx =
        if get_char_var(ctx, :mos_swan, 0) == 23, do: changequest(ctx, 18066, 18067), else: ctx

      close(ctx)
    else
      ctx
      |> mes("- You have pricked your finger on a Green Herb. -")
      |> give_item(511, 1)
      |> close()
    end
  end
end
