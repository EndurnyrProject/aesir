defmodule Aesir.ZoneServer.Content.Npc.Floating.ZombieGenerator do
  @moduledoc """
  Zombie wave controller of the final Priest job change test.

  ## Behavior

  - Enables the five zombie zone triggers and starts its timer when the trial
    begins.
  - Spawns the wave of the zone that just opened, three or two "sins" at a time,
    and keeps their total in `MyMobs`.
  - After five minutes it warps everyone in the hall back to Prontera and hands
    the trial back to Father Peter.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe) (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script jobs/2-1/priest.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @name "Zombie_Generator#prst"
  @room "job_prist"
  @on_mob_dead "Z_C#prst::OnMyMobDead"

  @zones ["Zombie1_1", "Zombie2_1", "Zombie3_1", "Zombie4_1", "Zombie5_1"]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @name)
  def on_event("OnEnable", ctx), do: start(ctx)
  def on_event("Onm1", ctx), do: spawn_wave(ctx, 13, [{24, 52}, {18, 52}, {30, 52}])
  def on_event("Onm2", ctx), do: spawn_wave(ctx, nil, [{21, 62}, {27, 62}])
  def on_event("Onm3", ctx), do: spawn_wave(ctx, nil, [{24, 72}, {18, 72}, {30, 72}])
  def on_event("Onm4", ctx), do: spawn_wave(ctx, nil, [{21, 82}, {27, 82}])
  def on_event("Onm5", ctx), do: spawn_wave(ctx, nil, [{24, 92}, {18, 92}, {30, 92}])

  def on_event("OnDisable", ctx) do
    ctx |> disablenpc(@name) |> killmonsterall(@room)
  end

  def on_event("OnTimer300000", ctx) do
    areawarp(ctx, @room, 8, 34, 39, 109, "prontera", 234, 318)
  end

  def on_event("OnTimer300500", ctx), do: donpcevent(ctx, "#{@name}::OnDisable")

  def on_event("OnTimer301500", ctx) do
    ctx
    |> donpcevent("#{@name}::OnDisable")
    |> donpcevent("Peter S. Alberto#2::OnDisable")
    |> donpcevent("Peter S. Alberto::OnEnable")
  end

  def on_event("OnTimer302000", ctx), do: stopnpctimer(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp start(ctx) do
    ctx =
      Enum.reduce(@zones, ctx, fn zone, ctx ->
        donpcevent(ctx, "#{zone}::OnEnable")
      end)

    initnpctimer(ctx)
  end

  defp spawn_wave(ctx, total, cells) do
    ctx = if total, do: set_npc_var(ctx, "MyMobs", total), else: ctx

    Enum.reduce(cells, ctx, fn {x, y}, ctx ->
      summon_mob(ctx, mob_id: 1015, map: @room, at: {x, y}, event: @on_mob_dead)
    end)
  end
end
