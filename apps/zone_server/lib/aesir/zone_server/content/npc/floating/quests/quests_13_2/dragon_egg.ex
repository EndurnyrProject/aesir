defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Quests132.DragonEgg do
  @moduledoc """
  Collects dragon eggs for the daily quest.

  ## Behavior

  - Checks carrying capacity and quest progress before awarding an egg.
  - Temporarily disables the egg after collection.

  ## Credits

  - Original from rAthena, authors and contributors:
    - L0ne_W0lf
    - Gepard
    - Masao
    - Euphy
    - Joseph
    - Jeybla
    - Mazvi

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{name: "Dragon Egg", unique_name: "Dragon Egg#ep13_degg_0"},
      %{
        map: "nyd_dun01",
        x: 258,
        y: 134,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg01"
      },
      %{
        map: "nyd_dun01",
        x: 100,
        y: 210,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg02"
      },
      %{
        map: "nyd_dun01",
        x: 74,
        y: 68,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg03"
      },
      %{
        map: "nyd_dun01",
        x: 98,
        y: 142,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg04"
      },
      %{
        map: "nyd_dun01",
        x: 244,
        y: 157,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg05"
      },
      %{
        map: "nyd_dun01",
        x: 59,
        y: 185,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg06"
      }
    ]

  @impl true
  def on_event("OnTimer420000", ctx), do: ctx |> enablenpc() |> stopnpctimer()
  def on_event("OnEnable", ctx), do: enablenpc(ctx)
  def on_event("OnDisable", ctx), do: disablenpc(ctx)

  @impl true
  def on_talk(ctx) do
    cond do
      checkweight(ctx, [{1201, 2}]) == 0 ->
        ctx |> mes("- You're carrying too many items. -") |> close()

      get_char_var(ctx, :ep13_2_dayegg, 0) == 1 and count_item(ctx, 6093) < 10 ->
        ctx
        |> mes("We just got fresh eggs from the dragon nest.")
        |> give_item(6093, 1)
        |> disablenpc()
        |> initnpctimer()
        |> close()

      true ->
        ctx
    end
  end
end
