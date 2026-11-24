defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsEin.EinbrochSmogAlert do
  @moduledoc """
  Einbroch Smog Alert runs the city's smog emergency for the Factory Quest.

  ## Behavior

  - When enabled, announces the emergency, hides the city's residents and fills Einbroch
    with Toxic Fog.
  - Ends the emergency once every fog is killed or after ten minutes, restoring the
    residents and resetting the city's pollution level.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Evera
    - MasterOfMuppets
    - Lupus
    - KarLaeda
    - SinSloth
    - L0ne_W0lf
    - Yommy
    - Paradox924X
    - Kisuka
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "einbroch",
        x: 1,
        y: 1,
        dir: 0,
        sprite: -1,
        name: "Einbroch Smog Alert",
        scope: :shared
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @fog_event "Einbroch Smog Alert::OnMyMobDead"

  @sheltered_npcs [
    "Centzu#ein",
    "Khowropher#ein",
    "Khetine#ein",
    "Sleik#ein",
    "Tollaf#ein",
    "Keneshiotz#ein",
    "Khashurantze#ein",
    "Kesunboss#ein",
    "Train Station Staff#ein1",
    "Train Station Staff#ein2",
    "Leslie#ein_1",
    "Tan#ein",
    "Little Toby#ein-1",
    "Airship Engineer#ein-1",
    "Kafra Employee#ein1",
    "Kafra Employee#ein2",
    "Kafra Employee#ein3",
    "Morei#ein",
    "Mark#ein",
    "Khemko#ein",
    "Oberu#ein",
    "Uwe Kleine#ein",
    "Flu Mask Dealer#ein",
    "Paddler#ein",
    "Laboratory Soldier#ein-1",
    "Laboratory Soldier#ein-2"
  ]

  @fog_cells [
    {{82, 332}, "Toxic Fog"},
    {{99, 328}, "Toxic Fog"},
    {{122, 317}, "Toxic Fog"},
    {{138, 319}, "Toxic Fog"},
    {{147, 312}, "Red Fog"},
    {{159, 316}, "Toxic Fog"},
    {{173, 315}, "Toxic Fog"},
    {{161, 311}, "Toxic Fog"},
    {{147, 296}, "Toxic Fog"},
    {{168, 282}, "Red Fog"},
    {{175, 271}, "Toxic Fog"},
    {{146, 274}, "Toxic Fog"},
    {{160, 272}, "Toxic Fog"},
    {{155, 256}, "Toxic Fog"},
    {{179, 262}, "Red Fog"},
    {{192, 248}, "Toxic Fog"},
    {{212, 255}, "Toxic Fog"},
    {{230, 250}, "Toxic Fog"},
    {{246, 251}, "Toxic Fog"},
    {{262, 254}, "Red Fog"},
    {{253, 240}, "Toxic Fog"},
    {{202, 245}, "Toxic Fog"},
    {{181, 251}, "Toxic Fog"},
    {{172, 238}, "Toxic Fog"},
    {{146, 242}, "Red Fog"},
    {{186, 226}, "Toxic Fog"},
    {{173, 239}, "Toxic Fog"},
    {{124, 248}, "Toxic Fog"},
    {{120, 234}, "Toxic Fog"},
    {{98, 234}, "Red Fog"},
    {{101, 219}, "Toxic Fog"},
    {{89, 208}, "Toxic Fog"},
    {{96, 191}, "Toxic Fog"},
    {{76, 194}, "Toxic Fog"},
    {{60, 196}, "Red Fog"},
    {{45, 194}, "Toxic Fog"},
    {{34, 201}, "Toxic Fog"},
    {{40, 184}, "Toxic Fog"},
    {{64, 173}, "Toxic Fog"},
    {{96, 173}, "Red Fog"},
    {{41, 155}, "Toxic Fog"},
    {{46, 131}, "Toxic Fog"},
    {{46, 108}, "Toxic Fog"},
    {{38, 93}, "Toxic Fog"},
    {{55, 86}, "Red Fog"},
    {{81, 81}, "Toxic Fog"},
    {{107, 82}, "Toxic Fog"},
    {{107, 104}, "Toxic Fog"},
    {{123, 73}, "Toxic Fog"},
    {{132, 87}, "Red Fog"},
    {{125, 63}, "Toxic Fog"},
    {{142, 64}, "Toxic Fog"},
    {{150, 52}, "Toxic Fog"},
    {{157, 37}, "Toxic Fog"},
    {{179, 39}, "Red Fog"},
    {{197, 46}, "Toxic Fog"},
    {{217, 67}, "Toxic Fog"},
    {{246, 54}, "Toxic Fog"},
    {{228, 110}, "Toxic Fog"},
    {{250, 118}, "Red Fog"},
    {{273, 127}, "Toxic Fog"},
    {{288, 138}, "Toxic Fog"},
    {{281, 160}, "Toxic Fog"},
    {{281, 192}, "Toxic Fog"},
    {{291, 201}, "Red Fog"},
    {{283, 218}, "Toxic Fog"},
    {{268, 216}, "Toxic Fog"},
    {{273, 196}, "Toxic Fog"},
    {{262, 164}, "Toxic Fog"},
    {{241, 180}, "Red Fog"},
    {{216, 205}, "Toxic Fog"},
    {{209, 198}, "Toxic Fog"},
    {{224, 177}, "Toxic Fog"},
    {{227, 163}, "Toxic Fog"},
    {{208, 166}, "Red Fog"},
    {{132, 87}, "Toxic Fog"},
    {{149, 119}, "Toxic Fog"},
    {{119, 36}, "Toxic Fog"},
    {{84, 155}, "Toxic Fog"},
    {{82, 107}, "Red Fog"}
  ]

  @impl true
  def on_talk(ctx), do: ctx

  @impl true
  def on_event("OnEnable", ctx) do
    ctx =
      ctx
      |> set_server_temp_var("AlrdEinPoll", 1)
      |> mapannounce(
        "einbroch",
        "This is a state of emercency! Harmful smog is reaching high levels of saturation. Residents of Einbroch must find shelter immediately.",
        1
      )
      |> enablenpc("Einbroch Smog Alert")

    ctx = @sheltered_npcs |> Enum.reduce(ctx, &hideonnpc(&2, &1)) |> initnpctimer()
    Enum.reduce(@fog_cells, ctx, &summon_fog/2)
  end

  def on_event("OnMyMobDead", ctx) do
    if Rathena.truthy?(mobcount(ctx, "einbroch", @fog_event)) do
      ctx
    else
      end_emergency(ctx)
    end
  end

  def on_event("OnTimer600000", ctx), do: end_emergency(ctx)

  defp summon_fog({cell, name}, ctx) do
    summon_mob(ctx, mob_id: 1621, map: "einbroch", at: cell, name: name, event: @fog_event)
  end

  defp end_emergency(ctx) do
    ctx =
      ctx
      |> killmonsterall("einbroch")
      |> mapannounce(
        "einbroch",
        "Emergency status is now cancelled. Air pollution levels are now within the safety zone.",
        1
      )
      |> disablenpc("Einbroch Smog Alert")
      |> hideoffnpc("Liotzburg#ein")

    @sheltered_npcs
    |> Enum.reduce(ctx, &hideoffnpc(&2, &1))
    |> set_server_temp_var("AlrdEinPoll", 0)
    |> set_server_var("EinPolution", 0)
    |> stopnpctimer()
  end
end
