defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.ElevatorOn do
  @moduledoc """
  Transfers players from the reception into the elevator.

  ## Behavior

  - Starts the elevator timeout and first guard wave.

  ## Credits

  - Original from rAthena, authors and Contributors
    - MasterOfMuppets
    - SinSloth
    - L0ne_W0lf
    - Zephyrus
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "jupe_ele_r",
        x: 10,
        y: 54,
        dir: 0,
        sprite: -1,
        name: "Elevator On",
        scope: :shared,
        unique_name: "Elevator On#ufe"
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Elevator On#ufe")
  end

  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("Elevator On#ufe") |> initnpctimer()
  end

  def on_event("OnTimer1000", ctx) do
    ctx
    |> mapwarp("jupe_ele_r", "jupe_ele", 42, 47)
    |> set_server_temp_var("JupeElevatorInUse2", 0)
    |> donpcevent("TimeOut#ufe::OnEnable")
    |> donpcevent("Guard-1#ufe::OnEnable")
  end

  def on_event("OnTimer10000", ctx) do
    ctx |> stopnpctimer() |> disablenpc("Elevator On#ufe")
  end
end
