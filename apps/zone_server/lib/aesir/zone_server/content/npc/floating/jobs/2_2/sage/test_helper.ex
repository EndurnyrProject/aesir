defmodule Aesir.ZoneServer.Content.Npc.Floating.Jobs.M22.Sage.TestHelper do
  @moduledoc """
  Announcer that closes the Sage job change exam after the final station.

  ## Behavior

  - On enable, starts a short timer that tells the candidate to finish the rest
    of the quest elsewhere, announces the end of the practical examination,
    warps everyone out of the arena back to Juno and reopens the waiting room.

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
  @bc_map 1

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Test Helper#sg")
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer2000", ctx),
    do:
      announce(
        ctx,
        "Please go back to where you came from and finish the rest of your job change quest."
      )

  def on_event("OnTimer4000", ctx),
    do:
      announce(ctx, "This is the end of practical examination. Next candidate, please get ready.")

  def on_event("OnTimer5000", ctx) do
    areawarp(ctx, @arena, 100, 82, 131, 113, "yuno_in03", 163, 180)
  end

  def on_event("OnTimer7000", ctx), do: announce(ctx, "Next candidate, please enter.")

  def on_event("OnTimer9000", ctx) do
    ctx
    |> disablenpc("Test Helper#sg")
    |> donpcevent("Waiting Room#sg::OnEnable")
    |> stopnpctimer()
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp announce(ctx, text), do: mapannounce(ctx, @arena, text, @bc_map)
end
