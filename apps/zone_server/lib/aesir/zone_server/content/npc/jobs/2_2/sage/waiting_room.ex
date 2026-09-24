defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Sage.WaitingRoom do
  @moduledoc """
  Hidden waiting room that sends one candidate at a time into the Sage practical examination
  arena.

  ## Behavior

  - Opens a one-person waiting room on startup.
  - Warps the waiting candidate into the arena, starts the first arena room, and closes the
    waiting room until the arena re-enables it.

  ## Credits

  - Original from rAthena, authors and Contributors
    - jAthena
    - Unknown Translator
    - Darkchild
    - L0ne_W0lf
    - Samuray22
    - Brainstorm
    - Kisuka

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_sage",
        x: 50,
        y: 165,
        dir: 4,
        sprite: 700,
        name: "Waiting Room",
        scope: :shared,
        unique_name: "Waiting Room#sg"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    ctx
    |> hideonnpc("Waiting Room#sg")
    |> waitingroom("Waiting Room", 20, "Waiting Room#sg::OnStartArena", 1)
    |> enablewaitingroomevent()
  end

  def on_event("OnStartArena", ctx) do
    ctx
    |> warpwaitingpc("job_sage", 116, 97)
    |> donpcevent("Arena#1::OnEnable")
    |> disablewaitingroomevent()
  end

  def on_event("OnEnable", ctx), do: enablewaitingroomevent(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
