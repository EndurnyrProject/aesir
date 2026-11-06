defmodule Aesir.ZoneServer.Content.Npc.Floating.Arena1 do
  @moduledoc """
  Third and final combat station of the Sage job change exam.

  ## Behavior

  - On enable, resets and hides the second station, spawns the single Academic
    Probation monster and announces the one-minute limit with a countdown.
  - When it dies it congratulates the candidate, sets `SAGE_Q` to 8, starts the
    test helper and hides itself; when the time runs out it clears the arena and
    warps everyone in it back to Juno.

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
  @name "Arena#Doorkeeper"
  @bc_map 1

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @name)
  def on_event("OnEnable", ctx), do: start(ctx)
  def on_event("OnReset", ctx), do: killmonsterall(ctx, @arena)

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc("Arena#3") |> disablenpc(@name)
  end

  def on_event("OnMyMobDead", ctx), do: count_kill(ctx)
  def on_event("OnTimer1000", ctx), do: announce(ctx, "3rd test - Time limit 1 minute.")
  def on_event("OnTimer30000", ctx), do: announce(ctx, "30 seconds remaining.")
  def on_event("OnTimer50000", ctx), do: announce(ctx, "10 seconds remaining.")

  def on_event("OnTimer60000", ctx) do
    ctx |> announce("Time over.") |> donpcevent("#{@name}::OnReset")
  end

  def on_event("OnTimer61000", ctx) do
    areawarp(ctx, @arena, 100, 82, 131, 113, "yuno", 324, 258)
  end

  def on_event("OnTimer62000", ctx), do: announce(ctx, "Next candidate, please enter.")

  def on_event("OnTimer63000", ctx) do
    ctx |> disablenpc(@name) |> donpcevent("Waiting Room#sg::OnEnable") |> stopnpctimer()
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp start(ctx) do
    ctx
    |> enablenpc(@name)
    |> donpcevent("Arena#2::OnReset")
    |> disablenpc("Arena#2")
    |> set_npc_var("MyMobs", 1)
    |> summon_mob(
      mob_id: 1179,
      map: @arena,
      at: {116, 97},
      event: "Arena#Doorkeeper::OnMyMobDead"
    )
    |> initnpctimer()
  end

  defp count_kill(ctx) do
    remaining = get_npc_var(ctx, "MyMobs", 0) - 1
    ctx = set_npc_var(ctx, "MyMobs", remaining)

    if remaining < 1 do
      ctx
      |> announce("Congratulations, " <> char_name(ctx, 0) <> ". You passed the test.")
      |> set_char_var(:SAGE_Q, 8)
      |> donpcevent("Test Helper#sg::OnEnable")
      |> disablenpc(@name)
      |> stopnpctimer()
    else
      ctx
    end
  end

  defp announce(ctx, text), do: mapannounce(ctx, @arena, text, @bc_map)
end
