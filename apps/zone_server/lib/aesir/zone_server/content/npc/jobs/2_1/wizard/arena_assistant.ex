defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Wizard.ArenaAssistant do
  @moduledoc """
  Queues Wizard candidates for the battle test arena and starts each run.

  ## Behavior

  - Explains the arena and hosts a waiting room that starts a run as soon as a candidate
    joins.
  - On each run, clears the arena, warps the candidate into the Water Room, and starts it,
    pausing the waiting room until the run ends.

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
        x: 50,
        y: 165,
        dir: 4,
        sprite: 700,
        name: "Arena Assistant",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    ctx
    |> waitingroom("Waiting Room", 20, "Arena Assistant::OnStartArena", 1)
    |> enablewaitingroomevent()
  end

  def on_event("OnStartArena", ctx) do
    ctx
    |> killmonsterall("job_wiz")
    |> warpwaitingpc("job_wiz", 114, 169)
    |> donpcevent("Room of Water::OnEnable")
    |> disablewaitingroomevent()
  end

  def on_event("OnStart", ctx), do: enablewaitingroomevent(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx) do
    ctx
    |> mes("[Arena Assistant]")
    |> mes("Welcome to the Wizard Job Change Arena.")
    |> mes("If you would like to take the final test, then please enter the waiting room.")
    |> next()
    |> mes("[Arena Assistant]")
    |> mes("If someone is already taking the test, please wait.")
    |> mes(
      "All testing status will be broadcasted, and will begin as soon as the previous tester has gone through."
    )
    |> next()
    |> mes("[Arena Assistant]")
    |> mes("Each person may take approximately 5 to 10 minutes.")
    |> mes("If you would like to leave the arena, please log off anytime.")
    |> close()
  end
end
