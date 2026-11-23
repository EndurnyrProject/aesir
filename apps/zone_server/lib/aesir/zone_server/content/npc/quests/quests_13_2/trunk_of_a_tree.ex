defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.TrunkOfATree do
  @moduledoc """
  Offers a climb out of the underground cave.

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
        map: "nyd_dun01",
        x: 62,
        y: 233,
        dir: 0,
        sprite: 844,
        name: "Trunk of a Tree",
        scope: :shared,
        unique_name: "Trunk of a Tree#ep13",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx) do
    {ctx, choice} =
      ctx
      |> mes("It's the trunk of a Tree stretched out toward a hole in the ceiling.")
      |> mes("Big thorns can be used as footholds.")
      |> next()
      |> select(["Climb up.", "Never mind."])

    case choice do
      1 -> warp(ctx, "spl_fild01", 376, 65)
      2 -> ctx |> mes("I'll come back later.") |> close()
      _ -> ctx
    end
  end

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("The trunk of a Tree moderately stretched upward.")
    |> mes("There are big thorns here that should be enough to use as footholds to climb up.")
    |> close()
  end
end
