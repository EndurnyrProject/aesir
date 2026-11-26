defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsRachel.Window do
  @moduledoc """
  An open window provides an exit from the temple.

  ## Behavior

  - The player may stay or exit through the window.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_rachel",
        x: 63,
        y: 82,
        dir: 0,
        sprite: 111,
        name: "Window",
        scope: :shared,
        unique_name: "Window#ra_temple"
      }
    ]

  @impl true
  def on_talk(ctx) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis window is open.^000000")
      |> next()
      |> select(["Stay", "Exit Through Window"])

    if choice == 2 do
      ctx |> close2() |> warp("ra_temple", 73, 208)
    else
      close(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
