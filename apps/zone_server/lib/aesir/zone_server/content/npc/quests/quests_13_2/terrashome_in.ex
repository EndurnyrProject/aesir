defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.TerrashomeIn do
  @moduledoc """
  Gates entry to Terra’s home by quest progress.

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
        map: "splendide",
        x: 287,
        y: 140,
        dir: 0,
        sprite: 45,
        name: "terrashome_in",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx), do: enter_home(ctx)

  @impl true
  def on_talk(ctx), do: enter_home(ctx)

  defp enter_home(ctx) do
    if get_char_var(ctx, :ep13_mdrama, 0) > 25 do
      warp(ctx, "spl_in02", 237, 89)
    else
      ctx |> mes("It's locked.") |> close()
    end
  end
end
