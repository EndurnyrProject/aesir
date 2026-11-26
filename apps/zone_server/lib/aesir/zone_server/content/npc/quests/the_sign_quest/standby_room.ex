defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.StandbyRoom do
  @moduledoc """
  Manages the waiting room for the dance examination.

  ## Behavior

  - Starts the arena when a player joins and reopens it on reset.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "cmd_in01",
        x: 33,
        y: 33,
        dir: 1,
        sprite: 66,
        name: "Standby Room",
        scope: :shared,
        unique_name: "Standby Room#sign"
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnStartArena", ctx), do: ev_onstartarena(ctx)
  def on_event("OnReset", ctx), do: ev_onreset(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_oninit(ctx) do
    ctx
    |> waitingroom("DANCE~ DANCE~", 20, "Standby Room#sign::OnStartArena", 1, 0, 50)
    |> enablewaitingroomevent()
  end

  def ev_onstartarena(ctx) do
    ctx
    |> donpcevent("s_dance_timer::OnButton_Off")
    |> donpcevent("Examiner#sd::OnDisable")
    |> warpwaitingpc("cmd_in01", 16, 15, 1)
    |> donpcevent("s_dance_timer::OnEnable")
    |> disablewaitingroomevent()
  end

  def ev_onreset(ctx), do: enablewaitingroomevent(ctx)
end
