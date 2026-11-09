defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.QueJob01114 do
  @moduledoc """
  Exit trigger of Master Zone Area 1 that sends the player back to the zone entrance and
  stops the area's timer (#room1timer).

  ## Behavior

  - Fires on touch and on talk, warping the player to `que_job01` 52,50.
  - Stops the area timer with `#room1timer::OnStop`.

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
        map: "que_job01",
        x: 11,
        y: 4,
        dir: 0,
        sprite: 45,
        name: "que_job01",
        scope: :shared,
        unique_name: "que_job01#room1_out",
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx), do: leave(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: leave(ctx)

  defp leave(ctx) do
    ctx
    |> warp("que_job01", 52, 50)
    |> donpcevent(" #room1timer::OnStop")
  end
end
