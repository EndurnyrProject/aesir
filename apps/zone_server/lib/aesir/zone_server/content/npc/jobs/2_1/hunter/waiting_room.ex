defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Hunter.WaitingRoom do
  @moduledoc """
  Waiting room that admits one Hunter examinee at a time into the test arena.

  ## Behavior

  - Opens a chat room on startup and sends its occupant into the arena.
  - Starts the arena manager and pauses admissions while a test is running.
  - Resumes admissions when the current test ends.

  ## Credits

  - Original from rAthena, authors and Contributors
    - EREMES THE CANIVALIZER
    - yoshiki
    - kobra_k88
    - Lupus
    - celest
    - Poki#3
    - Vicious
    - Silent
    - FlavioJS
    - Samuray22
    - L0ne_W0lf
    - Kisuka
    - Vali

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_hunte",
        x: 178,
        y: 38,
        dir: 1,
        sprite: 66,
        name: "Waiting Room",
        scope: :shared,
        unique_name: "Waiting Room#hnt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    ctx
    |> waitingroom("Waiting Room", 10, "Waiting Room#hnt::OnStartArena", 1)
    |> enablewaitingroomevent()
  end

  def on_event("OnStartArena", ctx) do
    ctx
    |> warpwaitingpc("job_hunte", 90, 67)
    |> donpcevent("Manager#hnt::OnEnable")
    |> disablewaitingroomevent()
  end

  def on_event("OnStart", ctx), do: enablewaitingroomevent(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
