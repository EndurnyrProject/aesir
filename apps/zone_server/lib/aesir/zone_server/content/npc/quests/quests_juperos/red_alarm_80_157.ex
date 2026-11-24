defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsJuperos.RedAlarm80157 do
  @moduledoc """
  Alarm tripwire past Juperos security checkpoint 2-4.

  ## Behavior

  - Armed when the checkpoint's crest device opens its portal.
  - Stepping on it starts the alarm sequence (Red Alarm On#2-4), marks the area as in use
    and shuts the crest device.

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
        map: "jupe_area2",
        x: 80,
        y: 157,
        dir: 0,
        sprite: -1,
        name: "Red Alarm",
        scope: :shared,
        unique_name: "Red Alarm#2-4",
        trigger: {2, 2}
      }
    ]

  @impl true
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Red Alarm#2-4")

  def on_event("OnEnable", ctx), do: enablenpc(ctx, "Red Alarm#2-4")

  def on_event("OnTouch_", ctx) do
    ctx
    |> set_server_temp_var("JupreArea2InUse", 1)
    |> donpcevent("Red Alarm On#2-4::OnEnable")
    |> disablenpc("Red Alarm#2-4")
    |> disablenpc("#hole#2-4")
  end

  @impl true
  def on_talk(ctx), do: on_event("OnInit", ctx)
end
