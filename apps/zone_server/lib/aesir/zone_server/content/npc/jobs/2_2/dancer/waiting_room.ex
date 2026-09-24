defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Dancer.WaitingRoom do
  @moduledoc """
  Waiting room that admits one candidate at a time to the Dancer job test arena.

  ## Behavior

  - Opens a single-seat waiting room at startup.
  - When a candidate enters, resets the arena tiles, warps the candidate in, starts the test timer,
    and closes the room until the test ends.

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

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_duncer",
        x: 32,
        y: 154,
        dir: 1,
        sprite: 66,
        name: "Waiting Room",
        scope: :shared,
        unique_name: "Waiting Room#dance"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    ctx
    |> waitingroom("Waiting Room", 20, "Waiting Room#dance::OnStartArena", 1)
    |> enablewaitingroomevent()
  end

  def on_event("OnStartArena", ctx) do
    ctx
    |> disablenpc("dance#up")
    |> disablenpc("dance#down")
    |> disablenpc("dance#left")
    |> disablenpc("dance#right")
    |> disablenpc("dance#cen")
    |> donpcevent("dance#return::OnDisable")
    |> warpwaitingpc("job_duncer", 69, 110, 1)
    |> donpcevent("Bijou#dance_timer::OnEnable")
    |> disablewaitingroomevent()
  end

  def on_event("OnEnable", ctx), do: enablewaitingroomevent(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
