defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Wizard.RoomOfEarth14 do
  @moduledoc """
  Controls the Earth Room guardian round of the Wizard job change battle test.

  ## Behavior

  - Closes the Earth Room, summons its guardians, and gives the candidate one minute.
  - Once every guardian is defeated, fully heals the candidate, moves them to the Fire
    Room, and starts it.
  - On time-up clears the room, briefly enables the failure warp, and calls the next
    candidate.

  ## Credits

  - Original from rAthena, authors and Contributors
    - yoshiki
    - kobra_k88
    - Lupus
    - L0ne_W0lf
    - Yommy
    - SoulBlaker
    - Kisuka
    - Vali
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "job_wiz",
        x: 1,
        y: 4,
        dir: 1,
        sprite: 66,
        name: "Room of Earth",
        scope: :shared,
        unique_name: "Room of Earth#Door"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Room of Earth#Door")

  def on_event("OnEnable", ctx) do
    ctx =
      ctx
      |> enablenpc("Room of Earth#Door")
      |> donpcevent("Room of Earth::OnDisable")

    ctx =
      if not Rathena.truthy?(checkre(ctx, 0)) do
        ctx
        |> set_npc_var("MyMobs", 7)
        |> summon_guardian(1118, 116, 97)
      else
        set_npc_var(ctx, "MyMobs", 6)
      end

    ctx
    |> summon_guardian(1020, 114, 95)
    |> summon_guardian(1020, 118, 95)
    |> summon_guardian(1020, 114, 99)
    |> summon_guardian(1020, 118, 99)
    |> summon_guardian(1020, 116, 94)
    |> summon_guardian(1020, 116, 100)
    |> initnpctimer()
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> killmonsterall("job_wiz")
    |> disablenpc("Room of Earth#Door")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> announce("#{char_name(ctx, 0)} has succeeded in eliminating the monster.")
      |> percent_heal(hp: 100, sp: 100)
      |> warp("job_wiz", 46, 99)
      |> donpcevent("Room of Earth#Door::OnDisable")
      |> donpcevent("Room of Fire::OnEnable")
      |> stopnpctimer()
    else
      ctx
    end
  end

  def on_event("OnTimer1000", ctx),
    do: announce(ctx, "The guard monster has appeared. You have 1 minute.")

  def on_event("OnTimer30000", ctx), do: announce(ctx, "30 seconds remaining.")
  def on_event("OnTimer50000", ctx), do: announce(ctx, "10 seconds remaining.")

  def on_event("OnTimer60000", ctx) do
    ctx
    |> announce("End time.")
    |> donpcevent("Room of Earth#Door::OnDisable")
  end

  def on_event("OnTimer61000", ctx), do: enablenpc(ctx, "Room of Earth#Failed")
  def on_event("OnTimer62000", ctx), do: announce(ctx, "Next candidate, please enter.")

  def on_event("OnTimer63000", ctx) do
    ctx
    |> disablenpc("Room of Earth#Failed")
    |> donpcevent("Room of Earth#Door::OnDisable")
    |> donpcevent("Arena Assistant::OnStart")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp summon_guardian(ctx, mob_id, x, y) do
    summon_mob(ctx,
      mob_id: mob_id,
      map: "job_wiz",
      at: {x, y},
      event: "Room of Earth#Door::OnMyMobDead"
    )
  end

  defp announce(ctx, message), do: mapannounce(ctx, "job_wiz", message, 1)
end
