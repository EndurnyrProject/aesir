defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.Summoner14 do
  @moduledoc """
  Fourth endurance test wave of the Crusader job quest: Familiars and Mushrooms.

  ## Behavior

  - Spawns its monster wave at boot and starts a timer.
  - When the timer expires, clears the wave, disables itself, and spawns a fresh wave.
  - Tags its monsters with the third wave's death event, so killing one warps the killer
    out through that wave while this wave's reset never clears them.

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
    {1005, {98, 50}},
    {1005, {98, 55}},
    {1005, {98, 60}},
    {1005, {98, 65}},
    {1005, {98, 70}},
    {1005, {98, 75}},
    {1005, {98, 80}},
    {1005, {98, 85}},
    {1005, {98, 90}},
    {1182, {90, 34}},
    {1182, {105, 34}}
  ]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTimer345000", ctx), do: donpcevent(ctx, "Summoner#cr4::OnReset")
  def on_event("OnTimer345500", ctx), do: donpcevent(ctx, "Summoner#cr4::OnEnd")

  def on_event("OnTimer346000", ctx),
    do: ctx |> donpcevent("Summoner#cr4::OnStart") |> stopnpctimer()

  def on_event("OnInit", ctx), do: spawn_wave(ctx)
  def on_event("OnStart", ctx), do: spawn_wave(ctx)
  def on_event("OnReset", ctx), do: killmonster(ctx, "job_cru", "Summoner#cr4::OnDead")
  def on_event("OnEnd", ctx), do: disablenpc(ctx, "Summoner#cr4")
  def on_event("OnDead", ctx), do: warp(ctx, "prt_fild05", 353, 251)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp spawn_wave(ctx) do
    ctx = enablenpc(ctx, "Summoner#cr4")

    @wave
    |> Enum.reduce(ctx, fn {mob_id, at}, ctx ->
      summon_mob(ctx, mob_id: mob_id, map: "job_cru", at: at, event: "Summoner#cr3::OnDead")
    end)
    |> initnpctimer()
  end
end
