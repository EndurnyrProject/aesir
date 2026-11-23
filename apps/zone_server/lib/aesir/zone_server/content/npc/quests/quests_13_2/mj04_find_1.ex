defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Mj04Find1 do
  @moduledoc """
  Handles an exploration trigger and displays quest markers.

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
        map: "mjolnir_04",
        x: 147,
        y: 208,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj04_find_1",
        trigger: {5, 5}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.Find132

  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnTouch_", ctx) do
    {ctx, _} = Find132.call(ctx, [0, 1])
    ctx |> viewpoint(1, 125, 380, 1, 65_280) |> viewpoint(1, 220, 130, 2, 65_280) |> close()
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
