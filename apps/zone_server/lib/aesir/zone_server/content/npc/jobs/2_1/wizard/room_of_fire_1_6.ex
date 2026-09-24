defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Wizard.RoomOfFire16 do
  @moduledoc """
  Controls the Fire Room guardian round, the final stage of the Wizard job change battle
  test.

  ## Behavior

  - Closes the Fire Room, summons its guardians, and gives the candidate two minutes.
  - Once every guardian is defeated, marks the battle test as passed, advances the quest
    log, and starts the Test Helper's closing announcements.
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
        y: 6,
        dir: 1,
        sprite: 66,
        name: "Room of Fire",
        scope: :shared,
        unique_name: "Room of Fire#Door"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Room of Fire#Door")

  def on_event("OnEnable", ctx) do
    ctx =
      ctx
      |> enablenpc("Room of Fire#Door")
      |> donpcevent("Room of Fire::OnDisable")
      |> set_npc_var("MyMobs", 3)
      |> summon_guardian(1277, 44, 99)

    ctx =
      if Rathena.truthy?(checkre(ctx, 0)) do
        ctx
        |> summon_guardian(1277, 43, 99)
        |> summon_guardian(1277, 45, 99)
      else
        ctx
        |> summon_guardian(1129, 43, 99)
        |> summon_guardian(1129, 45, 99)
      end

    initnpctimer(ctx)
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> killmonsterall("job_wiz")
    |> disablenpc("Room of Fire#Door")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> announce("Congratulations, #{char_name(ctx, 0)}. You have passed the job change test.")
      |> set_char_var(:WIZ_Q, 7)
      |> changequest(9017, 9018)
      |> donpcevent("Room of Fire#Door::OnDisable")
      |> donpcevent("Test Helper#wiz::OnEnable")
      |> stopnpctimer()
    else
      ctx
    end
  end

  def on_event("OnTimer1000", ctx),
    do: announce(ctx, "The guard monster has appeared. You have 2 minutes.")

  def on_event("OnTimer30000", ctx), do: announce(ctx, "1 minute and 30 seconds remaining.")
  def on_event("OnTimer60000", ctx), do: announce(ctx, "1 minute remaining.")
  def on_event("OnTimer90000", ctx), do: announce(ctx, "30 seconds remaining.")
  def on_event("OnTimer110000", ctx), do: announce(ctx, "10 seconds remaining.")

  def on_event("OnTimer120000", ctx) do
    ctx
    |> announce("Time is up.")
    |> donpcevent("Room of Fire#Door::OnDisable")
  end

  def on_event("OnTimer121000", ctx), do: enablenpc(ctx, "Room of Fire#Failed")
  def on_event("OnTimer122000", ctx), do: announce(ctx, "Next candidate, please enter.")

  def on_event("OnTimer123000", ctx) do
    ctx
    |> disablenpc("Room of Fire#Failed")
    |> donpcevent("Room of Fire#Door::OnDisable")
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
      event: "Room of Fire#Door::OnMyMobDead"
    )
  end

  defp announce(ctx, message), do: mapannounce(ctx, "job_wiz", message, 1)
end
