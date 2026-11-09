defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.MainStone01 do
  @moduledoc """
  Controls an Okolnir magic guardian formation.

  ## Behavior

  - Summons guardians and advances the boss encounter when the formation is defeated.
  - Removes remaining guardians when reset.

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
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#aru01_stone01"
      },
      %{
        map: "que_qaru02",
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#aru02_stone01"
      },
      %{
        map: "que_qaru03",
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#aru03_stone01"
      },
      %{
        map: "que_qaru04",
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#aru04_stone01"
      },
      %{
        map: "que_qaru05",
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#aru05_stone01"
      },
      %{
        map: "que_qsch01",
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#sch01_stone01"
      },
      %{
        map: "que_qsch02",
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#sch02_stone01"
      },
      %{
        map: "que_qsch03",
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#sch03_stone01"
      },
      %{
        map: "que_qsch04",
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#sch04_stone01"
      },
      %{
        map: "que_qsch05",
        x: 2,
        y: 8,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#sch05_stone01"
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
    {ctx, sub} = FOkolnir.call(ctx, [])

    Enum.reduce(
      [
        {227, 294},
        {229, 294},
        {231, 296},
        {231, 298},
        {230, 300},
        {228, 301},
        {226, 301},
        {224, 299},
        {224, 297},
        {225, 295}
      ],
      ctx,
      fn at, acc ->
        summon_mob(acc,
          mob_id: 1752,
          map: Rathena.concat("que_q", sub),
          at: at,
          event: Rathena.concat(Rathena.concat("#", sub), "_stone01::OnMyMobDead")
        )
      end
    )
  end

  def on_event("OnReset", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    killmonster(
      ctx,
      Rathena.concat("que_q", sub),
      Rathena.concat(Rathena.concat("#", sub), "_stone01::OnMyMobDead")
    )
  end

  def on_event("OnMyMobDead", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    map = Rathena.concat("que_q", sub)
    event = Rathena.concat(Rathena.concat("#", sub), "_stone01::OnMyMobDead")

    if mobcount(ctx, map, event) == 0 do
      finish_formation(ctx, sub)
    else
      ctx
    end
  end

  defp finish_formation(ctx, sub) do
    counter = Rathena.concat(Rathena.concat("$@gqse_", sub), "_nm")
    ctx = setd(ctx, counter, getd(ctx, counter) + 1)
    ctx = donpcevent(ctx, Rathena.concat(Rathena.concat("#nmsom", sub), "_jin01::OnDisable"))

    if getd(ctx, counter) == 3 do
      donpcevent(ctx, Rathena.concat(Rathena.concat("Wish Maiden#", sub), "_boss::OnFight"))
    else
      ctx
    end
  end
end
