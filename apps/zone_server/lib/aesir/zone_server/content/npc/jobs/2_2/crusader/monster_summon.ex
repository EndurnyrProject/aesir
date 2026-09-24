defmodule Aesir.ZoneServer.Content.Npc.Jobs.M22.Crusader.MonsterSummon do
  @moduledoc """
  Coordinates the undead waves of the Crusader purification test.

  ## Behavior

  - Starts the test by resetting the kill count and enabling every stage trigger and the timer.
  - Summons the zombie, skeleton, and archer skeleton/mummy waves on request.
  - Marks the purification test as passed once ten summoned monsters have died.
  - Clears the remaining monsters when the test resets.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Black Dragon
    - Shin
    - Samuray22
    - SinSloth
    - L0ne_W0lf
    - Lupus
    - Kisuka
    - Capuche
    - Komurka
    - massdriller
    - DracoRPG
    - Vicious

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc, scope: :shared, spawn: []

  alias Aesir.ZoneServer.Script.Ctx

  @on_dead "Monster Summon#cr0::OnDead"

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, "Monster Summon#cr0")

  def on_event("OnStart", ctx) do
    ctx
    |> set_npc_var("MyMonsterCount", 0)
    |> enablenpc("Monster Summon#cr0")
    |> donpcevent("Monster Summon#cr1::OnStart")
    |> donpcevent("Monster Summon#cr2::OnStart")
    |> donpcevent("Monster Summon#cr3::OnStart")
    |> donpcevent("Monster Summon#cr4::OnStart")
    |> donpcevent("Monster Summon#cr6::OnStart")
  end

  def on_event("OnMonster1", ctx), do: summon_wave(ctx, List.duplicate({1015, {168, 45}}, 6))
  def on_event("OnMonster2", ctx), do: summon_wave(ctx, List.duplicate({1028, {168, 80}}, 3))

  def on_event("OnMonster3", ctx),
    do: summon_wave(ctx, [{1016, {168, 110}}, {1041, {168, 115}}])

  def on_event("OnDead", ctx) do
    ctx = set_npc_var(ctx, "MyMonsterCount", get_npc_var(ctx, "MyMonsterCount", 0) + 1)

    if get_npc_var(ctx, "MyMonsterCount", 0) >= 10 do
      ctx |> set_char_var(:CRUS_Q, 10) |> changequest(3014, 3015)
    else
      ctx
    end
  end

  def on_event("OnEnd", ctx), do: disablenpc(ctx, "Monster Summon#cr0")
  def on_event("OnReset", ctx), do: killmonster(ctx, "job_cru", @on_dead)

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  defp summon_wave(ctx, monsters) do
    Enum.reduce(monsters, ctx, fn {mob_id, at}, ctx ->
      summon_mob(ctx, mob_id: mob_id, map: "job_cru", at: at, event: @on_dead)
    end)
  end
end
