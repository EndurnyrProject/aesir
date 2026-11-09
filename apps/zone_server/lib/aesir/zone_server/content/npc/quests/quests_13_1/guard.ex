defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.Guard do
  @moduledoc """
  A Lighthalzen gate guard of the three-kingdom registration, who checks the player's
  standing through the shared `Guard_13_1` dialog.

  ## Behavior

  - Runs the shared guard dialog on a click with the walk-in argument, and on touch with the
    touch argument, so a touch also walks the player to the gate when it refuses them.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "lhz_in01",
        x: 115,
        y: 250,
        dir: 3,
        sprite: 899,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#ep13_1-1",
        trigger: {2, 2}
      },
      %{
        map: "lhz_in01",
        x: 115,
        y: 252,
        dir: 3,
        sprite: 899,
        name: "Guard",
        scope: :shared,
        unique_name: "Guard#ep13_1-2",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.Guard131
  alias Aesir.ZoneServer.Script.Ctx

  @gate [108, 252]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    enter(ctx, 1)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    enter(ctx, 0)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp enter(ctx, touch) do
    {ctx, _} = Guard131.call(ctx, [touch | @gate])
    ctx
  end
end
