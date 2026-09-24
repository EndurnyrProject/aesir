defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.Summoner12 do
  @moduledoc """
  Second endurance test wave of the Crusader job quest: Floras that must not be killed.

  ## Behavior

  - Spawns its monster wave at boot and starts a timer.
  - When the timer expires, clears the wave, disables itself, and spawns a fresh wave.
  - Warps a player out of the test field for killing one of its monsters.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Black Dragon
    - Shin
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - Lupus
    - Kisuka
    - Capuche
    - Komurka
    - massdriller
    - DracoRPG
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @wave [
    {1118, {98, 50}},
    {1118, {92, 60}},
    {1118, {104, 60}},
    {1118, {98, 70}},
    {1118, {92, 80}},
    {1118, {104, 90}},
    {1118, {98, 90}}
  ]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTimer345000", ctx), do: donpcevent(ctx, "Summoner#cr2::OnReset")
  def on_event("OnTimer345500", ctx), do: donpcevent(ctx, "Summoner#cr2::OnEnd")

  def on_event("OnTimer346000", ctx),
    do: ctx |> donpcevent("Summoner#cr2::OnStart") |> stopnpctimer()

  def on_event("OnInit", ctx), do: spawn_wave(ctx)
  def on_event("OnStart", ctx), do: spawn_wave(ctx)
  def on_event("OnReset", ctx), do: killmonster(ctx, "job_cru", "Summoner#cr2::OnDead")
  def on_event("OnEnd", ctx), do: disablenpc(ctx, "Summoner#cr2")
  def on_event("OnDead", ctx), do: warp(ctx, "prt_fild05", 353, 251)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp spawn_wave(ctx) do
    ctx = enablenpc(ctx, "Summoner#cr2")

    @wave
    |> Enum.reduce(ctx, fn {mob_id, at}, ctx ->
      summon_mob(ctx, mob_id: mob_id, map: "job_cru", at: at, event: "Summoner#cr2::OnDead")
    end)
    |> initnpctimer()
  end
end
