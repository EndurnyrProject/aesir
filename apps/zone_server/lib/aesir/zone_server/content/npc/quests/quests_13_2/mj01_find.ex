defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests132.Mj01Find do
  @moduledoc """
  Marks mineral search locations when a player enters the trigger.

  ## Credits

  - Original from rAthena, authors and Contributors
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
        map: "mjolnir_01",
        x: 364,
        y: 256,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#mj01_find",
        trigger: {5, 5}
      }
    ]

  @impl true
  def on_event("OnTouch_", ctx) do
    find_minerals(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx), do: ctx

  defp find_minerals(ctx) do
    {ctx, _} = Aesir.ZoneServer.Content.Npc.Functions.Find132.call(ctx, [0, 1])
    ctx |> viewpoint(1, 32, 309, 1, 65_280) |> viewpoint(1, 217, 34, 2, 65_280) |> close()
  end
end
