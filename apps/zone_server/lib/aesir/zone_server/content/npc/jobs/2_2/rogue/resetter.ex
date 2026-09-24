defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Rogue.Resetter do
  @moduledoc """
  Periodically clears leftover monsters from the Rogue job test tunnel.

  ## Behavior

  - Starts its timer on boot.
  - Disables every tunnel ambush trigger when the timer runs out, then restarts the timer.

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

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTimer500000", ctx) do
    ctx
    |> donpcevent("mob_rogue#1::OnDisable")
    |> donpcevent("mob_rogue#2::OnDisable")
    |> donpcevent("mob_rogue#3::OnDisable")
    |> donpcevent("mob_rogue#4::OnDisable")
    |> donpcevent("mob_rogue#5::OnDisable")
    |> donpcevent("mob_rogue#6::OnDisable")
    |> donpcevent("mob_rogue#7::OnDisable")
    |> donpcevent("mob_rogue#8::OnDisable")
    |> donpcevent("mob_rogue#9::OnDisable")
    |> donpcevent("mob_rogue#10::OnDisable")
    |> donpcevent("mob_rogue#12::OnDisable")
    |> donpcevent("mob_rogue#13::OnDisable")
    |> donpcevent("mob_rogue#15::OnDisable")
    |> initnpctimer()
  end

  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnInit", ctx), do: donpcevent(ctx, "resetter#rogue::OnEnable")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
