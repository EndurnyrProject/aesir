defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Priest.Zombie21 do
  @moduledoc """
  Invisible trigger that releases the second wave of zombies in the Priest spiritual training.

  ## Behavior

  - Starts disabled and is toggled through its enable and disable events.
  - When an Acolyte steps on it, asks the Zombie Generator to summon its wave and disables itself.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - KarLaeda
    - L0ne_W0lf
    - Samuray22
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
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Zombie2_1")

  def on_event("OnTouch", ctx) do
    if Rathena.job_id(base_job(ctx)) == Rathena.job_id(:acolyte) do
      ctx |> donpcevent("Zombie_Generator#prst::Onm2") |> donpcevent("Zombie2_1::OnDisable")
    else
      ctx
    end
  end

  def on_event("OnEnable", ctx), do: enablenpc(ctx, "Zombie2_1")
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "Zombie2_1")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
