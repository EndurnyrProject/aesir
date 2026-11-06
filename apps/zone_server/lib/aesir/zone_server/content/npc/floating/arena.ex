defmodule Aesir.ZoneServer.Content.Npc.Floating.Arena do
  @moduledoc """
  First combat station of the Sage job change exam.

  ## Behavior

  - On enable, spawns eight Grade F and eight Grade D monsters in the exam
    arena, counts sixteen kills and announces the three-minute limit with a
    countdown.
  - When the last monster dies it congratulates the candidate and opens the
    second station; when the time runs out it clears the arena and warps
    everyone in it back to Juno.

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
  @on_mob_dead "Arena#1::OnMyMobDead"
  @bc_map 1

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Arena#1")
  def on_event("OnEnable", ctx), do: start(ctx)
  def on_event("OnReset", ctx), do: killmonsterall(ctx, @arena)
  def on_event("OnMyMobDead", ctx), do: count_kill(ctx)

  def on_event("OnTimer1000", ctx),
    do: announce(ctx, "The practical examination has started.")

  def on_event("OnTimer2000", ctx), do: announce(ctx, "1st test - time limit 3 minutes.")

  def on_event("OnTimer3000", ctx),
    do: announce(ctx, "Please defeat all the monsters within the time limit.")

  def on_event("OnTimer33000", ctx), do: announce(ctx, "2 minutes 30 seconds remaining.")
  def on_event("OnTimer63000", ctx), do: announce(ctx, "2 minutes remaining.")
  def on_event("OnTimer93000", ctx), do: announce(ctx, "1 minute 30 seconds remaining.")
  def on_event("OnTimer123000", ctx), do: announce(ctx, "1 min remaining.")
  def on_event("OnTimer153000", ctx), do: announce(ctx, "30 seconds remaining.")
  def on_event("OnTimer173000", ctx), do: announce(ctx, "10 seconds remaining.")

  def on_event("OnTimer183000", ctx) do
    ctx |> announce("Time over.") |> donpcevent("Arena#1::OnReset")
  end

  def on_event("OnTimer184000", ctx) do
    areawarp(ctx, @arena, 100, 82, 131, 113, "yuno", 324, 258)
  end

  def on_event("OnTimer185000", ctx), do: announce(ctx, "Next candidate, enter.")

  def on_event("OnTimer186000", ctx) do
    ctx |> disablenpc("Arena#1") |> donpcevent("Waiting Room#sg::OnEnable") |> stopnpctimer()
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp start(ctx) do
    ctx
    |> enablenpc("Arena#1")
    |> set_npc_var("MyMobs", 16)
    |> summon(1183, [{111, 102}, {120, 102}, {111, 93}, {120, 93}, {107, 98}, {124, 98}])
    |> summon(1183, [{115, 106}, {115, 90}])
    |> summon(1184, [{103, 110}, {128, 110}, {103, 85}, {128, 85}])
    |> summon(1184, [{107, 106}, {124, 106}, {107, 89}, {124, 89}])
    |> initnpctimer()
  end

  defp summon(ctx, mob_id, cells) do
    Enum.reduce(cells, ctx, fn {x, y}, ctx ->
      summon_mob(ctx, mob_id: mob_id, map: @arena, at: {x, y}, event: @on_mob_dead)
    end)
  end

  defp count_kill(ctx) do
    remaining = get_npc_var(ctx, "MyMobs", 0) - 1
    ctx = set_npc_var(ctx, "MyMobs", remaining)

    if remaining < 1 do
      ctx
      |> announce(" " <> char_name(ctx, 0) <> ", successfully defeat all the monsters.")
      |> donpcevent("Arena#2::OnEnable")
      |> stopnpctimer()
    else
      ctx
    end
  end

  defp announce(ctx, text), do: mapannounce(ctx, @arena, text, @bc_map)
end
