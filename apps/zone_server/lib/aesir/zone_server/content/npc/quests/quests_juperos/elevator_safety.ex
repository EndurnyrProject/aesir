defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.ElevatorSafety do
  @moduledoc """
  Opens the elevator after the reception guards are defeated.

  ## Behavior

  - Announces the victory and starts the elevator transfer.

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
        y: 52,
        dir: 0,
        sprite: -1,
        name: "Elevator Safety",
        scope: :shared,
        unique_name: "Elevator Safety#ufe"
      }
    ]

  @impl true
  def on_talk(ctx) do
    on_event("OnInit", ctx)
  end

  @impl true
  def on_event("OnInit", ctx) do
    disablenpc(ctx, "Elevator Safety#ufe")
  end

  def on_event("OnEnable", ctx) do
    ctx |> enablenpc("Elevator Safety#ufe") |> initnpctimer()
  end

  def on_event("OnTimer5000", ctx) do
    ctx
    |> mapannounce(
      "jupe_ele_r",
      "Those of you who have defeated the hallucination, step forward.",
      1,
      "0x66FF00"
    )
    |> soundeffectall("earth_quake.wav", 0)
  end

  def on_event("OnTimer8000", ctx) do
    donpcevent(ctx, "Elevator On#ufe::OnEnable")
  end

  def on_event("OnTimer10000", ctx) do
    ctx |> disablenpc("Elevator Safety#ufe") |> stopnpctimer()
  end
end
