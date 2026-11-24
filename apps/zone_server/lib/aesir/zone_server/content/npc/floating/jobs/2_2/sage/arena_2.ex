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

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: [%{name: "Arena", unique_name: "Arena#3"}]

  @arena "job_sage"

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Arena#3")

  def on_event("OnEnable", ctx) do
    ctx
    |> summon(1185, {107, 106}, "Absent 3 times")
    |> summon(1185, {124, 106}, "Being Late 5 times")
    |> summon(1185, {107, 89}, "Cheating 2 times")
    |> summon(1185, {124, 89}, "Cheating 4 times")
  end

  def on_event("OnDisable", ctx), do: killmonsterall(ctx, @arena)

  defp summon(ctx, mob_id, {x, y}, name) do
    summon_mob(ctx, mob_id: mob_id, map: @arena, at: {x, y}, name: name)
  end

  @impl true
  def on_talk(ctx), do: ctx
end
