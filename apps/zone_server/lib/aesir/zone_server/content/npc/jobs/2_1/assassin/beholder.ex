defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Assassin.Beholder do
  @moduledoc """
  Controller for the timed Assassin target test, where applicants must kill only the
  marked target monsters among decoys.

  ## Behavior

  - Spawns six targets and a crowd of look-alike decoys, then runs a three-minute
    countdown with map announcements.
  - Killing all six targets advances the quest, opens the door to the hiding test, and
    disarms the traps.
  - Killing a decoy, or running out of time, sends the applicant back and resets the test.

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

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @target_event "Beholder#ASNTEST::OnMyMobDead"
  @decoy_event "Beholder#ASNTEST::OnMyMobDead2"

  @targets [
    {1002, {62, 161}},
    {1063, {85, 169}},
    {1002, {88, 152}},
    {1113, {90, 143}},
    {1031, {74, 167}},
    {1002, {77, 173}}
  ]

  @decoys [
    {1063, {62, 161}},
    {1031, {85, 169}},
    {1113, {79, 174}},
    {1063, {85, 156}},
    {1002, {74, 171}},
    {1113, {68, 173}},
    {1002, {65, 158}},
    {1113, {60, 158}},
    {1002, {64, 169}},
    {1063, {71, 173}},
    {1002, {77, 172}},
    {1063, {76, 172}},
    {1113, {75, 172}},
    {1063, {67, 167}},
    {1031, {86, 170}},
    {1002, {86, 171}},
    {1113, {85, 170}},
    {1063, {89, 171}},
    {1031, {85, 170}},
    {1002, {89, 156}},
    {1113, {89, 156}},
    {1063, {89, 156}},
    {1113, {89, 156}},
    {1031, {89, 156}},
    {1002, {83, 169}},
    {1063, {63, 158}},
    {1002, {63, 157}},
    {1002, {64, 159}},
    {1063, {63, 159}},
    {1002, {63, 159}},
    {1002, {63, 159}},
    {1002, {83, 148}},
    {1002, {82, 148}},
    {1002, {84, 148}}
  ]

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    ctx
    |> set_npc_var("MyMobs", 6)
    |> summon_all(@targets, @target_event)
    |> summon_all(@decoys, @decoy_event)
    |> initnpctimer()
  end

  def on_event("OnReset", ctx) do
    ctx
    |> kill_test_monsters()
    |> stopnpctimer()
    |> donpcevent("Standby Room#ASNTEST::OnStart")
  end

  def on_event("OnResetmob", ctx) do
    ctx
    |> kill_test_monsters()
    |> stopnpctimer()
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> mapannounce("in_moc_16", "You seem to be doing quite well. Keep it up!", 1)
      |> set_char_var(:ASSIN_Q, 3)
      |> changequest(8003, 8004)
      |> donpcevent("timestopper#1::OnEnable")
      |> donpcevent("Keeper of the Door#ASN::OnEnable")
      |> donpcevent("Beholder#ASNTEST::OnResetmob")
      |> set_npc_var("DisableTraps", 1)
      |> stopnpctimer()
    else
      announce(ctx, "Okay, you're doing good! Hang in there, you're almost there!")
    end
  end

  def on_event("OnMyMobDead2", ctx) do
    ctx
    |> announce("#{char_name(ctx, 0)}! You made a mistake! I'm bringing you back!")
    |> set_char_var(:ASSIN_Q, 2)
    |> warp("in_moc_16", 19, 161)
    |> donpcevent("Beholder#ASNTEST::OnReset")
  end

  def on_event("OnTimer1000", ctx), do: announce(ctx, " Okay, let the test begin!")

  def on_event("OnTimer2000", ctx) do
    announce(
      ctx,
      "As you've been told before, find and only kill monsters named 'Job change target!'"
    )
  end

  def on_event("OnTimer3000", ctx) do
    announce(
      ctx,
      "The purpose of this test is to examine your ability to quickly distinguish enemies from other people!"
    )
  end

  def on_event("OnTimer4000", ctx) do
    announce(
      ctx,
      "You will have 3 minutes for the test! We will inform you of every minute passed."
    )
  end

  def on_event("OnTimer5000", ctx) do
    announce(ctx, "Ok, now you've got exactly 3 minutes. Move! Move!")
  end

  def on_event("OnTimer65000", ctx) do
    announce(ctx, "2 minutes left. As I've told you, get the 'Job change target' monsters!")
  end

  def on_event("OnTimer125000", ctx), do: announce(ctx, "1 minute left.")
  def on_event("OnTimer180000", ctx), do: announce(ctx, "5 seconds left...")
  def on_event("OnTimer181000", ctx), do: announce(ctx, "4 seconds left...")
  def on_event("OnTimer182000", ctx), do: announce(ctx, "3 seconds left...")
  def on_event("OnTimer183000", ctx), do: announce(ctx, "2 seconds left...")
  def on_event("OnTimer184000", ctx), do: announce(ctx, "1 second left.")

  def on_event("OnTimer185000", ctx) do
    ctx
    |> announce("Time's up!")
    |> announce("Well, good job... If you wanted to waste your time. You'll have to try again!")
  end

  def on_event("OnTimer186000", ctx) do
    areawarp(ctx, "in_moc_16", 60, 136, 93, 177, "in_moc_16", 19, 161)
  end

  def on_event("OnTimer187000", ctx), do: donpcevent(ctx, "Beholder#ASNTEST::OnReset")

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp summon_all(ctx, mobs, event) do
    Enum.reduce(mobs, ctx, fn {mob_id, at}, ctx ->
      summon_mob(ctx, mob_id: mob_id, map: "in_moc_16", at: at, event: event)
    end)
  end

  defp kill_test_monsters(ctx) do
    ctx
    |> killmonster("in_moc_16", @target_event)
    |> killmonster("in_moc_16", @decoy_event)
  end

  defp announce(ctx, message), do: mapannounce(ctx, "in_moc_16", message, 1)
end
