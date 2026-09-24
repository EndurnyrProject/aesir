defmodule Aesir.ZoneServer.Content.Npc.Jobs.M21.Wizard.RoomOfWater12 do
  @moduledoc """
  Controls the Water Room guardian round of the Wizard job change battle test.

  ## Behavior

  - Closes the Water Room, summons its guardians, and gives the candidate one minute.
  - Once every guardian is defeated, fully heals the candidate, moves them to the Earth
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
        y: 2,
        dir: 1,
        sprite: 66,
        name: "Room of Water",
        scope: :shared,
        unique_name: "Room of Water#Door"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Room of Water#Door")

  def on_event("OnEnable", ctx) do
    ctx
    |> enablenpc("Room of Water#Door")
    |> donpcevent("Room of Water::OnDisable")
    |> set_npc_var("MyMobs", 5)
    |> summon_guardian(1142, 114, 169)
    |> summon_guardian(1068, 112, 169)
    |> summon_guardian(1068, 116, 169)
    |> summon_guardian(1068, 114, 171)
    |> summon_guardian(1068, 114, 167)
    |> initnpctimer()
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> killmonsterall("job_wiz")
    |> disablenpc("Room of Water#Door")
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = set_npc_var(ctx, "MyMobs", get_npc_var(ctx, "MyMobs", 0) - 1)

    if get_npc_var(ctx, "MyMobs", 0) < 1 do
      ctx
      |> announce("#{char_name(ctx, 0)} has succeeded in eliminating the monsters.")
      |> percent_heal(hp: 100, sp: 100)
      |> warp("job_wiz", 116, 97)
      |> donpcevent("Room of Water#Door::OnDisable")
      |> donpcevent("Room of Earth::OnEnable")
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
    |> announce("Time is up.")
    |> donpcevent("Room of Water#Door::OnDisable")
  end

  def on_event("OnTimer61000", ctx), do: enablenpc(ctx, "Room of Water#Failed")
  def on_event("OnTimer62000", ctx), do: announce(ctx, "Next candidate, please enter.")

  def on_event("OnTimer63000", ctx) do
    ctx
    |> disablenpc("Room of Water#Failed")
    |> donpcevent("Room of Water#Door::OnDisable")
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
      event: "Room of Water#Door::OnMyMobDead"
    )
  end

  defp announce(ctx, message), do: mapannounce(ctx, "job_wiz", message, 1)
end
