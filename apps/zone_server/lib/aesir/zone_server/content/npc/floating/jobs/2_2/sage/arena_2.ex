defmodule Aesir.ZoneServer.Content.Npc.Floating.Jobs.M22.Sage.Arena2 do
  @moduledoc """
  Summoned "excuses" of the final Sage job change station.

  ## Behavior

  - Spawns the four monsters whose names hold the candidate back and clears the
    arena again when the station is disabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Darkchild
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-2/sage.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @arena "job_sage"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Arena#3")

  def on_event("OnEnable", ctx) do
    ctx
    |> summon(1185, {107, 106})
    |> summon(1185, {124, 106})
    |> summon(1185, {107, 89})
    |> summon(1185, {124, 89})
  end

  def on_event("OnDisable", ctx), do: killmonsterall(ctx, @arena)

  defp summon(ctx, mob_id, {x, y}) do
    summon_mob(ctx, mob_id: mob_id, map: @arena, at: {x, y})
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
