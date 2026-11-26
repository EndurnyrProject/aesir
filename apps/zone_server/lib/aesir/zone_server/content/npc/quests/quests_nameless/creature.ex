defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Creature do
  @moduledoc """
  A hidden creature guards the monastery.

  ## Behavior

  - Spawns a zombie during the investigation and enables the exit after its defeat.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "nameless_in",
        x: 13,
        y: 53,
        dir: 1,
        sprite: 1864,
        name: "Creature",
        scope: :shared,
        unique_name: "Creature#Monas",
        trigger: {3, 1}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnInit", ctx), do: ev_oninit(ctx)
  def on_event("OnTouch", ctx), do: ev_ontouch(ctx)
  def on_event("OnMyMobDead", ctx), do: ev_onmymobdead(ctx)
  @impl true
  def on_talk(ctx), do: ctx

  def ev_oninit(ctx) do
    hideonnpc(ctx, "Creature#Monas")
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :aru_monas, 0) == 19 and
         mobcount(ctx, "nameless_in", "Creature#Monas::OnMyMobDead") < 1 and
         not Rathena.truthy?(get_temp_var(ctx, :aru_monas_kill, 0)) do
      ctx
      |> mes("[???????]")
      |> mes("Grrr~!!!")
      |> close2()
      |> summon_mob(
        mob_id: 1864,
        map: "nameless_in",
        at: {13, 53},
        name: "Zombie",
        event: "Creature#Monas::OnMyMobDead"
      )
      |> hideonnpc("Creature#Monas")
    else
      ctx
    end
  end

  def ev_onmymobdead(ctx) do
    ctx |> set_temp_var(:aru_monas_kill, 1) |> enablenpc("Out_from_Monastery")
  end
end
