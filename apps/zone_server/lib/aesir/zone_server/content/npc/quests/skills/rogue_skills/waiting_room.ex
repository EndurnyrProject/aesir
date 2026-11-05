defmodule Aesir.ZoneServer.Content.Npc.Quests.Skills.RogueSkills.WaitingRoom do
  @moduledoc """
  Waiting room that sends a Rogue into the Close Confine training ground.

  ## Behavior

  - Opens a one-player "Training Ground" waiting room on startup.
  - When the room fills, warps the waiting player into the training arena and locks the room
    until the round is over and the room is enabled again.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Lupus
    - Reddozen
    - 2Spiritual Kid
    - DracoRPG
    - L0ne_W0lf
    - Samuray22
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_rogue",
        x: 88,
        y: 119,
        dir: 3,
        sprite: 828,
        name: "Waiting Room",
        scope: :shared,
        unique_name: "Waiting Room#rogue10"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("Waiting Room#rogue10") |> enablewaitingroomevent("Waiting Room#rogue10")
  end

  def on_event("OnInit", ctx) do
    ctx
    |> waitingroom("Training Ground", 10, "Waiting Room#rogue10::OnStartArena", 1)
    |> enablewaitingroomevent("Waiting Room#rogue10")
  end

  def on_event("OnStartArena", ctx) do
    ctx |> warpwaitingpc("prt_are01", 150, 150) |> disablewaitingroomevent("Waiting Room#rogue10")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  # rAthena starts a click at the first label, so it runs this body too.
  def on_talk(ctx), do: on_event("OnEnable", ctx)
end
