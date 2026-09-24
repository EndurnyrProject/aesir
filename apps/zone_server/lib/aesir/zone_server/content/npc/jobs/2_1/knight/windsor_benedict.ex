defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Knight.WindsorBenedict do
  @moduledoc """
  Hidden waiting room host for the Knight combat test arena.

  ## Behavior

  - Opens a one-person waiting room that starts the combat test when entered.
  - Starting the test clears leftover stage monsters, warps the candidate into the
    first stage, and closes the waiting room until the test ends.

  ## Credits

  - Original from rAthena, authors and Contributors
    - PGRO TEAM (Aegis)
    - kobra_k88
    - Lupus
    - Vicious
    - L0ne_W0lf
    - Samuray22
    - Kisuka
    - Vali
    - Euphy
    - Joseph

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_knt",
        x: 89,
        y: 106,
        dir: 4,
        sprite: 733,
        name: "Windsor Benedict",
        scope: :shared,
        unique_name: "Windsor Benedict#knt"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    ctx
    |> hideonnpc("Windsor Benedict#knt")
    |> waitingroom("Waiting Room", 20, "Windsor Benedict#knt::OnStartArena", 1)
    |> enablewaitingroomevent()
  end

  def on_event("OnStartArena", ctx) do
    ctx
    |> killmonster("job_knt", "Knight1::OnMyMobDead")
    |> killmonster("job_knt", "Knight2::OnMyMobDead")
    |> killmonster("job_knt", "Knight3::OnMyMobDead")
    |> warpwaitingpc("job_knt", 43, 146)
    |> donpcevent("Knight1::OnEnable")
    |> disablewaitingroomevent()
  end

  def on_event("OnStart", ctx), do: enablewaitingroomevent(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
