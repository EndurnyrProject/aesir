defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.GodWeaponCreation.GodHopewarp1 do
  @moduledoc """
  Waiting room at the god item laboratory entrance that lets one player in at a time.

  ## Behavior

  - Opens a two-seat "Laboratory Entrance" waiting room at boot.
  - When a player joins, they are warped into the laboratory, Grunburti is enabled and the room
    stops accepting entries until it is reset.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - L0ne_W0lf
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_god01",
        x: 215,
        y: 127,
        dir: 0,
        sprite: 111,
        name: "",
        scope: :shared,
        unique_name: "#god_hopewarp1"
      }
    ]

  @impl true
  def on_event("OnInit", ctx) do
    ctx
    |> waitingroom("Laboratory Entrance", 2, "#god_hopewarp1::OnStartArena", 1)
    |> enablewaitingroomevent()
  end

  def on_event("OnStartArena", ctx) do
    ctx
    |> warpwaitingpc("que_god01", 155, 63)
    |> donpcevent("Grunburti#god::OnEnable")
    |> disablewaitingroomevent()
  end

  def on_event("OnReset", ctx), do: enablewaitingroomevent(ctx)

  @impl true
  def on_talk(ctx), do: ctx
end
