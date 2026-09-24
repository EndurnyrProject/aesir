defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Wizard.TestHelper do
  @moduledoc """
  Closes a successful Wizard battle test run and reopens the arena for the next candidate.

  ## Behavior

  - Announces the end of the test, warps everyone out of the arena back to the Wizard
    tower, and restarts the Arena Assistant's waiting room.

  ## Credits

  - Original from rAthena, authors and Contributors
    - yoshiki
    - kobra_k88
    - Lupus
    - L0ne_W0lf
    - Yommy
    - SoulBlaker
    - Kisuka
    - Vali
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_wiz",
        x: 1,
        y: 7,
        dir: 1,
        sprite: 66,
        name: "Test Helper",
        scope: :shared,
        unique_name: "Test Helper#wiz"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Test Helper#wiz")
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)
  def on_event("OnDisable", ctx), do: disablenpc(ctx, "Test Helper#wiz")

  def on_event("OnTimer2000", ctx),
    do: announce(ctx, "Please return and complete the rest of the job change processes.")

  def on_event("OnTimer4000", ctx),
    do: announce(ctx, "This is the end of the test. Next candidate, please stand by.")

  def on_event("OnTimer5000", ctx),
    do: areawarp(ctx, "job_wiz", 33, 82, 57, 113, "gef_tower", 110, 30)

  def on_event("OnTimer7000", ctx), do: announce(ctx, "Next candidate, please enter.")

  def on_event("OnTimer9000", ctx) do
    ctx
    |> donpcevent("Test Helper#wiz::OnDisable")
    |> donpcevent("Arena Assistant::OnStart")
    |> stopnpctimer()
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp announce(ctx, message), do: mapannounce(ctx, "job_wiz", message, 1)
end
