defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.Timer do
  @moduledoc """
  Controller of the Knight patience test arena.

  ## Behavior

  - On enable, fills the arena with passive monsters and starts the test timer.
  - Killing any of those monsters fails the test and ejects the candidate to the
    Prontera fields.
  - After five minutes, reveals the exit portal, then clears the arena, hides the
    portal, and restarts the cycle.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_knt",
        x: 1,
        y: 1,
        dir: 1,
        sprite: 107,
        name: "Timer",
        scope: :shared,
        unique_name: "Timer#knt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @mob_event "Timer#knt::OnMyMobDead"

  @arena_mobs [
    {1002, {141, 57}},
    {1002, {145, 57}},
    {1002, {143, 55}},
    {1002, {143, 59}},
    {1063, {141, 55}},
    {1063, {141, 59}},
    {1063, {145, 55}},
    {1063, {145, 59}},
    {1011, {139, 57}},
    {1011, {147, 57}},
    {1011, {143, 53}},
    {1011, {143, 61}},
    {1182, {165, 54}},
    {1182, {165, 57}},
    {1182, {122, 54}},
    {1182, {122, 57}}
  ]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTimer300000", ctx), do: enablenpc(ctx, "Warp#knt")

  def on_event("OnTimer300500", ctx) do
    ctx
    |> donpcevent("Timer#knt::OnDisable")
    |> disablenpc("Warp#knt")
  end

  def on_event("OnTimer301500", ctx) do
    ctx
    |> stopnpctimer()
    |> donpcevent("Timer#knt::OnEnable")
  end

  def on_event("OnInit", ctx), do: ctx

  def on_event("OnEnable", ctx) do
    @arena_mobs
    |> Enum.reduce(enablenpc(ctx, "Timer#knt"), fn {mob_id, at}, ctx ->
      summon_mob(ctx, mob_id: mob_id, map: "job_knt", at: at, event: @mob_event)
    end)
    |> initnpctimer()
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> killmonster("job_knt", @mob_event)
    |> disablenpc("Timer#knt")
    |> disablenpc("Warp#knt")
  end

  def on_event("OnMyMobDead", ctx), do: warp(ctx, "prt_fild05", 353, 251)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
