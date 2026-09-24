defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.MobRogue86187 do
  @moduledoc """
  Springs a monster ambush on Rogue candidates in the job test tunnel.

  ## Behavior

  - Summons three Mummies when a Thief steps into its trigger area.
  - Warps any other character out of the tunnel.
  - Removes the monsters it summoned when disabled.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @mob_dead_event "mob_rogue#12::OnMyMobDead"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:thief) do
      ctx
      |> summon_mob(mob_id: 1041, map: "in_rogue", at: {90, 187}, event: @mob_dead_event)
      |> summon_mob(mob_id: 1041, map: "in_rogue", at: {90, 183}, event: @mob_dead_event)
      |> summon_mob(mob_id: 1041, map: "in_rogue", at: {90, 190}, event: @mob_dead_event)
    else
      warp(ctx, "mag_dun02", 181, 176)
    end
  end

  def on_event("OnDisable", ctx), do: killmonster(ctx, "in_rogue", @mob_dead_event)
  def on_event("OnMyMobDead", ctx), do: ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
