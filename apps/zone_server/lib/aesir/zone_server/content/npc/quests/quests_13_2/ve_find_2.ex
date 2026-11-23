defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.VeFind2 do
  @moduledoc """
  Reveals mineral deposits when the detector search is triggered.

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
        map: "ve_fild03",
        x: 223,
        y: 51,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#ve_find_2",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.Find132

  @impl true
  def on_event("OnTouch_", ctx) do
    {ctx, _} = Find132.call(ctx, [2, 1])

    ctx
    |> viewpoint(1, 152, 134, 1, 65_280)
    |> viewpoint(1, 256, 228, 2, 65_280)
    |> viewpoint(1, 85, 189, 3, 65_280)
    |> viewpoint(1, 282, 268, 4, 65_280)
    |> close()
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx), do: ctx
end
