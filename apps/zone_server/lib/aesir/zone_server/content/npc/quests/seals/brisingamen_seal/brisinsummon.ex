defmodule Aesir.ZoneServer.Content.Npc.Quests.Seals.BrisingamenSeal.Brisinsummon do
  @moduledoc """
  Controls the Brisingamen Seal's vision and monster encounter.

  ## Behavior

  - Shows and hides actors during the vision and resets the scene.
  - Summons nine monsters and reveals the Valkyrie after their deaths.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Toms
    - L0ne_W0lf
    - Samuray22
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
        map: "que_god02",
        x: 1,
        y: 1,
        dir: 1,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#brisinsummon"
      }
    ]

  @mob_death_event "#brisinsummon::OnMobDeath"

  @encounter_mobs [
    {1015, {34, 128}},
    {1015, {34, 127}},
    {1015, {80, 127}},
    {1036, {102, 128}},
    {1036, {130, 128}},
    {1041, {62, 128}},
    {1041, {64, 127}},
    {1041, {150, 127}},
    {1041, {176, 127}}
  ]

  @impl true
  def on_event("OnInit", ctx), do: hide_vision(ctx)
  def on_event("OnDoppel1On", ctx), do: hideoffnpc(ctx, "#doppelganger1")
  def on_event("OnDoppel1Off", ctx), do: hideonnpc(ctx, "#doppelganger1")
  def on_event("OnDoppel2On", ctx), do: hideoffnpc(ctx, "#doppelganger2")
  def on_event("OnDoppel2Off", ctx), do: hideonnpc(ctx, "#doppelganger2")
  def on_event("OnKnight1On", ctx), do: hideoffnpc(ctx, "#knight1")
  def on_event("OnKnight2On", ctx), do: hideoffnpc(ctx, "#knight2")
  def on_event("OnKnight3On", ctx), do: hideoffnpc(ctx, "#knight3")
  def on_event("OnKnight1Off", ctx), do: hideonnpc(ctx, "#knight1")
  def on_event("OnKnight2Off", ctx), do: hideonnpc(ctx, "#knight2")
  def on_event("OnKnight3Off", ctx), do: hideonnpc(ctx, "#knight3")
  def on_event("OnLowenOn", ctx), do: hideoffnpc(ctx, "#lowen")
  def on_event("OnLowenOff", ctx), do: hideonnpc(ctx, "#lowen")
  def on_event("OnHermiteOff", ctx), do: hideonnpc(ctx, "#hermite")
  def on_event("OnLowen2Off", ctx), do: hideonnpc(ctx, "Lowen Ellenen#2")
  def on_event("OnSummon", ctx), do: summon_encounter(ctx)
  def on_event("OnMobDeath", ctx), do: count_encounter_death(ctx)
  def on_event("OnReset", ctx), do: reset_scene(ctx)

  @impl true
  def on_talk(ctx), do: hide_vision(ctx)

  defp hide_vision(ctx) do
    ctx
    |> hideonnpc("#doppelganger1")
    |> hideonnpc("#doppelganger2")
    |> hideonnpc("#knight1")
    |> hideonnpc("#knight2")
    |> hideonnpc("#knight3")
    |> hideonnpc("#lowen")
    |> hideonnpc("Valkyrie#1")
    |> hideoffnpc("#hermite")
  end

  defp summon_encounter(ctx) do
    ctx = set_npc_var(ctx, "brisinmobdead", 9)

    Enum.reduce(@encounter_mobs, ctx, fn {mob_id, at}, ctx ->
      summon_mob(ctx, mob_id: mob_id, map: "que_god02", at: at, name: "", event: @mob_death_event)
    end)
  end

  defp count_encounter_death(ctx) do
    ctx = set_npc_var(ctx, "brisinmobdead", get_npc_var(ctx, "brisinmobdead", 0) - 1)

    if get_npc_var(ctx, "brisinmobdead", 0) > 0 do
      ctx
    else
      ctx |> set_char_var(:god_brising, 31) |> hideoffnpc("Valkyrie#1")
    end
  end

  defp reset_scene(ctx) do
    ctx
    |> hideonnpc("#doppelganger1")
    |> hideonnpc("#doppelganger2")
    |> hideonnpc("#knight1")
    |> hideonnpc("#knight2")
    |> hideonnpc("#knight3")
    |> hideonnpc("#lowen")
    |> hideoffnpc("Soldier#1_brising")
    |> hideonnpc("Soldier#2_brising")
    |> hideoffnpc("#hermite")
    |> hideoffnpc("Lowen Ellenen#2")
    |> hideonnpc("Valkyrie#1")
    |> killmonster("que_god02", @mob_death_event)
  end
end
