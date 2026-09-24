defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.StandbyRoom do
  @moduledoc """
  Waiting room that admits one applicant at a time to the Assassin target test.

  ## Behavior

  - Opens a hidden one-person waiting room at startup.
  - Sends applicants who have not passed the written test back to the exam entrance.
  - Otherwise starts the target test, closes the door to the next room, arms the traps,
    and stops admitting applicants until the test is reset.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Pgro Team (OwNaGe)
    - kobra_k88
    - Lupus
    - Vicious
    - Silent
    - Toms
    - L0ne_W0lf
    - Samuray22
    - Zephyrus_cr
    - brianluau
    - Kisuka
    - JayPee
    - Euphy
    - MrAntares
    - Atemo

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "in_moc_16",
        x: 21,
        y: 165,
        dir: 2,
        sprite: 725,
        name: "Standby Room",
        scope: :shared,
        unique_name: "Standby Room#ASNTEST"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx) do
    ctx
    |> hideonnpc("Standby Room#ASNTEST")
    |> waitingroom("Standby Room", 10, "Standby Room#ASNTEST::OnStartArena", 1)
    |> enablewaitingroomevent()
  end

  def on_event("OnStartArena", ctx) do
    ctx = warpwaitingpc(ctx, "in_moc_16", 66, 151)
    {ctx, _} = attachrid(ctx, Enum.at(get_server_temp_var(ctx, "warpwaitingpc", []), 0, 0))

    if get_char_var(ctx, :ASSIN_Q2, 0) < 5 do
      warpchar(ctx, "in_moc_16", 20, 145, getcharid(ctx, 0))
    else
      ctx
      |> donpcevent("Beholder#ASNTEST::OnEnable")
      |> donpcevent("Keeper of the Door#ASN::OnDisable")
      |> set_npc_var_of("DisableTraps", "Beholder#ASNTEST", 0)
      |> disablewaitingroomevent()
    end
  end

  def on_event("OnStart", ctx), do: enablewaitingroomevent(ctx)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx
end
