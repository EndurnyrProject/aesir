defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.WaitingRoom do
  @moduledoc """
  Hidden waiting room that queues candidates for the Crusader purification test.

  ## Behavior

  - Opens the waiting room at boot; it triggers as soon as one candidate is waiting.
  - Warps the waiting candidate into the arena, starts the test, and stops triggering.
  - Resumes triggering when the test ends.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Black Dragon
    - Shin
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - Lupus
    - Kisuka
    - Capuche
    - Komurka
    - massdriller
    - DracoRPG
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_cru",
        x: 24,
        y: 187,
        dir: 2,
        sprite: 700,
        name: "Waiting Room",
        scope: :shared,
        unique_name: "Waiting Room#cr1"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    ctx
    |> hideonnpc("Waiting Room#cr1")
    |> waitingroom("Waiting Room", 20, "Waiting Room#cr1::OnStartArena", 1)
    |> enablewaitingroomevent()
  end

  def on_event("OnStartArena", ctx) do
    ctx
    |> warpwaitingpc("job_cru", 168, 21)
    |> donpcevent("Monster Summon#cr0::OnStart")
    |> disablewaitingroomevent()
  end

  def on_event("OnStart", ctx), do: enablewaitingroomevent(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
