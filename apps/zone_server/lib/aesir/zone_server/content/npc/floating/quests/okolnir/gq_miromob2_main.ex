defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.GqMiromob2Main do
  @moduledoc """
  Controls the Mystic Garden's summoned enemies.

  ## Behavior

  - Announces and summons waves of enemies in the garden.
  - Opens the garden exit when they are defeated and removes them on reset.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Joseph
    - L0ne_W0lf
    - Toshiro90
    - Euphy

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script quests/okolnir.txt
  - LLM-assisted Elixir refactor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "que_qaru01",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_aru01"
      },
      %{
        map: "que_qaru02",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_aru02"
      },
      %{
        map: "que_qaru03",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_aru03"
      },
      %{
        map: "que_qaru04",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_aru04"
      },
      %{
        map: "que_qaru05",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_aru05"
      },
      %{
        map: "que_qsch01",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_sch01"
      },
      %{
        map: "que_qsch02",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_sch02"
      },
      %{
        map: "que_qsch03",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_sch03"
      },
      %{
        map: "que_qsch04",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_sch04"
      },
      %{
        map: "que_qsch05",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gq_miromob2_sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    {ctx, _sub} = FOkolnir.call(ctx, [])
    initnpctimer(ctx)
  end

  def on_event("OnTimer1000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    mapannounce(
      ctx,
      Rathena.concat("que_q", sub),
      "Wish Maiden: How does it feel to see shadows of the past. This is only the beginning.",
      1,
      "0x00ff00"
    )
  end

  def on_event("OnTimer6000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx =
      mapannounce(
        ctx,
        Rathena.concat("que_q", sub),
        "Wish Maiden: The things you seeing are not real, don't be caught in the Mystic garden.",
        1,
        "0x00ff00"
      )

    enemies = [
      {72, 271, 1640},
      {63, 282, 1645},
      {59, 294, 1644},
      {46, 300, 1643},
      {51, 285, 1641},
      {51, 262, 1642}
    ]

    ctx = Enum.reduce(1..3, ctx, fn _, acc -> summon_wave(acc, sub, enemies) end)
    stopnpctimer(ctx)
  end

  def on_event("OnReset", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> killmonster(Rathena.concat("que_q", sub), death_event(sub)) |> stopnpctimer()
  end

  def on_event("OnMyMobDead", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    map = Rathena.concat("que_q", sub)

    if mobcount(ctx, map, death_event(sub)) == 0 do
      ctx
      |> mapannounce("que_qaru05", "The Mystic garden exit is now open.", 1, "0x00ff00")
      |> setcell(map, 58, 302, 63, 302, :walkable, 1)
      |> setcell(map, 58, 302, 63, 302, :shootable, 1)
      |> donpcevent(Rathena.concat(Rathena.concat("#Maze_Manager_", sub), "::OnDisable"))
    else
      ctx
    end
  end

  defp summon_wave(ctx, sub, enemies) do
    Enum.reduce(enemies, ctx, fn {x, y, mob}, acc ->
      summon_mob(acc,
        mob_id: mob,
        map: Rathena.concat("que_q", sub),
        at: {x, y},
        event: death_event(sub)
      )
    end)
  end

  defp death_event(sub), do: Rathena.concat(Rathena.concat("#gq_miromob2_", sub), "::OnMyMobDead")
end
