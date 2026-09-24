defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.MobRogue233207 do
  @moduledoc """
  Clears earlier ambushes from the Rogue job test tunnel as a Thief passes.

  ## Behavior

  - Disables other tunnel ambush triggers when a Thief steps into its trigger area.
  - Warps any other character out of the tunnel.

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

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch", ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:thief) do
      donpcevent(ctx, "mob_rogue#13::OnDisable")
    else
      warp(ctx, "mag_dun02", 181, 176)
    end
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
