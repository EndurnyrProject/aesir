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
    {82, 332},
    {99, 328},
    {122, 317},
    {138, 319},
    {147, 312},
    {159, 316},
    {173, 315},
    {161, 311},
    {147, 296},
    {168, 282},
    {175, 271},
    {146, 274},
    {160, 272},
    {155, 256},
    {179, 262},
    {192, 248},
    {212, 255},
    {230, 250},
    {246, 251},
    {262, 254},
    {253, 240},
    {202, 245},
    {181, 251},
    {172, 238},
    {146, 242},
    {186, 226},
    {173, 239},
    {124, 248},
    {120, 234},
    {98, 234},
    {101, 219},
    {89, 208},
    {96, 191},
    {76, 194},
    {60, 196},
    {45, 194},
    {34, 201},
    {40, 184},
    {64, 173},
    {96, 173},
    {41, 155},
    {46, 131},
    {46, 108},
    {38, 93},
    {55, 86},
    {81, 81},
    {107, 82},
    {107, 104},
    {123, 73},
    {132, 87},
    {125, 63},
    {142, 64},
    {150, 52},
    {157, 37},
    {179, 39},
    {197, 46},
    {217, 67},
    {246, 54},
    {228, 110},
    {250, 118},
    {273, 127},
    {288, 138},
    {281, 160},
    {281, 192},
    {291, 201},
    {283, 218},
    {268, 216},
    {273, 196},
    {262, 164},
    {241, 180},
    {216, 205},
    {209, 198},
    {224, 177},
    {227, 163},
    {208, 166},
    {132, 87},
    {149, 119},
    {119, 36},
    {84, 155},
    {82, 107}
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

  defp summon_fog(cell, ctx) do
    summon_mob(ctx, mob_id: 1621, map: "einbroch", at: cell, event: @fog_event)
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
