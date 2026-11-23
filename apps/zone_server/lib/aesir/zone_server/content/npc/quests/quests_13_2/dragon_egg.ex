defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.DragonEgg do
  @moduledoc """
  Provides dragon eggs for the daily collection quest.

  ## Behavior

  - Gives an egg to eligible players and temporarily disables the nest.
  - Handles enable, disable, and timer events.

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
      %{
        map: "nyd_dun02",
        x: 68,
        y: 256,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg_1"
      },
      %{
        map: "nyd_dun02",
        x: 68,
        y: 256,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg11"
      },
      %{
        map: "nyd_dun02",
        x: 202,
        y: 166,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg12"
      },
      %{
        map: "nyd_dun02",
        x: 200,
        y: 165,
        dir: 0,
        sprite: 463,
        name: "Dragon Egg",
        scope: :shared,
        unique_name: "Dragon Egg#ep13_degg13"
      }
    ]

  @impl true
  def on_event("OnTimer240000", ctx), do: ctx |> enablenpc() |> stopnpctimer()
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
