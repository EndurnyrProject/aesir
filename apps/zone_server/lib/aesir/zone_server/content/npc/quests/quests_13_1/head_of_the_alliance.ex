defmodule Aesir.ZoneServer.Content.Npc.Quests.Quests131.HeadOfTheAlliance do
  @moduledoc """
  The head of the alliance on the rift battlefield, who orders the fifteen-minute assault
  on the adventurers.

  ## Behavior

  - Hides itself on boot, on a click and on the reset event.
  - When enabled announces the assault order, reveals itself, flags `$@ep13_test` as 1, starts
    its timer and summons 80 soldiers bound to its own death event.
  - When disabled clears the soldiers, announces the withdrawal, flags `$@ep13_test` as 0 and
    hides itself.
  - Once fewer than 41 soldiers remain it disables itself.
  - After fifteen minutes clears the soldiers, announces the withdrawal, flags `$@ep13_test` as
    2, hides itself and stops the timer.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/quests_13_1.txt
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "moc_fild22b",
        x: 1,
        y: 1,
        dir: 0,
        sprite: -1,
        name: "Head of the Alliance",
        scope: :shared,
        unique_name: "Head of the Alliance#moo"
      }
    ]

  alias Aesir.ZoneServer.Script.Ctx

  @npc "Head of the Alliance#moo"
  @map "moc_fild22b"
  @mob_event "Head of the Alliance#moo::OnMyMobDead"
  @soldier 1851
  @soldiers 80
  @remaining_soldiers 41

  @assault_order "Head of the Alliance: I command that all soldiers attack the adventurers around here for 15 minutes. This is an order!"
  @withdrawal_order "Head of the Alliance: All alliance members. All of you should stop your attacks and return to work. That's all."

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: disablenpc(ctx, @npc)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnInit", ctx), do: disablenpc(ctx, @npc)
  def on_event("OnReset", ctx), do: killmonster(ctx, @map, @mob_event)

  def on_event("OnEnable", ctx) do
    ctx
    |> mapannounce(@map, @assault_order, 1)
    |> enablenpc(@npc)
    |> set_server_temp_var("ep13_test", 1)
    |> initnpctimer()
    |> summon_mob(mob_id: @soldier, map: @map, at: :random, amount: @soldiers, event: @mob_event)
  end

  def on_event("OnDisable", ctx) do
    ctx
    |> killmonster(@map, @mob_event)
    |> mapannounce(@map, @withdrawal_order, 1)
    |> set_server_temp_var("ep13_test", 0)
    |> disablenpc(@npc)
  end

  def on_event("OnMyMobDead", ctx) do
    if mobcount(ctx, @map, @mob_event) < @remaining_soldiers do
      donpcevent(ctx, "#{@npc}::OnDisable")
    else
      ctx
    end
  end

  def on_event("OnTimer900000", ctx) do
    ctx
    |> killmonster(@map, @mob_event)
    |> mapannounce(@map, @withdrawal_order, 1)
    |> set_server_temp_var("ep13_test", 2)
    |> disablenpc(@npc)
    |> stopnpctimer()
  end
end
