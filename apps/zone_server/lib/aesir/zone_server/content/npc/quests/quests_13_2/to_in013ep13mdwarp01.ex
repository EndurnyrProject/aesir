defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.ToIn013ep13mdwarp01 do
  @moduledoc """
  Routes a doorway according to quest progress.

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
        map: "man_in01",
        x: 183,
        y: 58,
        dir: 0,
        sprite: 45,
        name: "to_in013ep13mdwarp01",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  @impl true
  def on_event("OnTouch", ctx), do: enter_door(ctx)

  @impl true
  def on_talk(ctx), do: enter_door(ctx)

  defp enter_door(ctx) do
    progress = get_char_var(ctx, :ep13_mdrama, 0)

    cond do
      progress > 23 -> warp(ctx, "man_in01", 68, 125)
      progress > 17 -> warp(ctx, "man_in01", 13, 125)
      true -> ctx |> mes("The doors are locked... I can't get in.") |> close()
    end
  end
end
