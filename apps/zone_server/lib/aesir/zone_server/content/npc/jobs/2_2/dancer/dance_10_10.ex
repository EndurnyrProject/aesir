defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.Dance1010 do
  @moduledoc """
  Spawns the Poring target used in the Dancer job test's final stage.

  ## Behavior

  - Summons a Poring into the test arena when enabled and clears the arena's monsters when disabled.
  - Announces success to the arena when the Poring is killed.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kalen
    - Fredzilla
    - Lupus
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka
    - Euphy
    - Vicious
    - Lance
    - Skotlex

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    summon_mob_area(ctx,
      mob_id: 1002,
      map: "job_duncer",
      area: {68, 105, 70, 107},
      event: "dance#poring::OnMyMobDead"
    )
  end

  def on_event("OnMyMobDead", ctx), do: mapannounce(ctx, "job_duncer", " Good! Well done! ", 1)
  def on_event("OnDisable", ctx), do: killmonsterall(ctx, "job_duncer")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
