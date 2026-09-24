defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Wizard.RoomOfWater do
  @moduledoc """
  Controls the Water Room stage of the Wizard job change battle test.

  ## Behavior

  - Summons water monsters when the arena starts and announces the three-minute countdown.
  - Once every monster is defeated, increments the candidate's battle test attempt counter
    and summons the Water Room guardians.
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
      %{map: "job_wiz", x: 1, y: 1, dir: 1, sprite: 66, name: "Room of Water", scope: :shared}
    ]

  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Room of Water")

  def on_event("OnEnable", ctx) do
    ctx = enablenpc(ctx, "Room of Water")

    ctx =
      if not Rathena.truthy?(checkre(ctx, 0)) do
        ctx
        |> set_npc_var("MyMobs", 8)
        |> summon_room_mob(1044, 129, 170)
      else
        set_npc_var(ctx, "MyMobs", 7)
      end

    ctx
    |> summon_room_mob(1158, 109, 174)
    |> summon_room_mob(1074, 118, 174)
    |> summon_room_mob(1066, 109, 165)
    |> summon_room_mob(1067, 118, 165)
    |> summon_room_mob(1141, 101, 157)
    |> summon_room_mob(1242, 126, 157)
    |> summon_room_mob(1138, 98, 170)
    |> initnpctimer()
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> killmonsterall("job_wiz")
    |> disablenpc("Room of Water")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> set_char_var(:WIZ_Q2, get_char_var(ctx, :WIZ_Q2, 0) + 1)
      |> announce("#{char_name(ctx, 0)} has succeeded in eliminating the monsters.")
      |> donpcevent("Room of Water#Door::OnEnable")
      |> stopnpctimer()
    else
      ctx
    end
  end

  def on_event("OnTimer1000", ctx),
    do: announce(ctx, "Water Room; The job change test will now proceed.")

  def on_event("OnTimer2000", ctx),
    do: announce(ctx, "Time limit is 3 minutes. We will now start the test.")

  def on_event("OnTimer3000", ctx),
    do: announce(ctx, "Please eliminate all monsters within the time limit.")

  def on_event("OnTimer33000", ctx), do: announce(ctx, "2 minutes and 30 seconds remaining.")
  def on_event("OnTimer63000", ctx), do: announce(ctx, "2 minutes remaining.")
  def on_event("OnTimer93000", ctx), do: announce(ctx, "1 minute and 30 seconds remaining.")
  def on_event("OnTimer123000", ctx), do: announce(ctx, "1 minute remaining.")
  def on_event("OnTimer153000", ctx), do: announce(ctx, "30 seconds remaining.")
  def on_event("OnTimer173000", ctx), do: announce(ctx, "10 seconds remaining.")

  def on_event("OnTimer183000", ctx) do
    ctx
    |> announce("Time is up.")
    |> donpcevent("Room of Water::OnDisable")
  end

  def on_event("OnTimer184000", ctx), do: enablenpc(ctx, "Room of Water#Failed")
  def on_event("OnTimer185000", ctx), do: announce(ctx, "Next candidate, please enter.")

  def on_event("OnTimer186000", ctx) do
    ctx
    |> disablenpc("Room of Water#Failed")
    |> donpcevent("Room of Water::OnDisable")
    |> donpcevent("Arena Assistant::OnStart")
  end

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp summon_room_mob(ctx, mob_id, x, y) do
    summon_mob(ctx,
      mob_id: mob_id,
      map: "job_wiz",
      at: {x, y},
      event: "Room of Water::OnMyMobDead"
    )
  end

  defp announce(ctx, message), do: mapannounce(ctx, "job_wiz", message, 1)
end
