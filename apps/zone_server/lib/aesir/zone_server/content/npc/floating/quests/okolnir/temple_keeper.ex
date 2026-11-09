defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.TempleKeeper do
  @moduledoc """
  Controls the temple keeper ambushes.

  ## Behavior

  - Summons temple keepers when a player touches an ambush trigger.
  - Disables triggers and removes their monsters when requested.

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
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru01_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru01",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru01_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru02_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru02_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru03_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru03_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru04_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru04_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru05_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#aru05_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch01_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch01_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch02_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch02_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch03_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch03_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch04_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch04_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 247,
        y: 330,
        dir: 5,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch05_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 255,
        y: 330,
        dir: 3,
        sprite: 1933,
        name: "Temple Keeper",
        scope: :shared,
        unique_name: "Temple Keeper#sch05_ac02",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @keepers %{
    1 => [{246, 330}, {247, 330}, {248, 330}],
    2 => [{254, 330}, {255, 330}, {256, 330}]
  }

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    {ctx, sub, keeper} = keeper_identity(ctx)

    ctx
    |> disablenpc(keeper_name(sub, keeper))
    |> summon_keepers(sub, keeper)
  end

  def on_event("OnDisable", ctx) do
    {ctx, sub, keeper} = keeper_identity(ctx)
    name = keeper_name(sub, keeper)

    ctx
    |> killmonster("que_q#{sub}", "#{name}::OnMyMobDead")
    |> disablenpc(name)
  end

  def on_event("OnMyMobDead", ctx), do: ctx

  def on_event("OnInit", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> then(fn ctx -> Enum.reduce([1, 2], ctx, &disablenpc(&2, keeper_name(sub, &1))) end)
  end

  defp summon_keepers(ctx, sub, keeper) do
    @keepers
    |> Map.get(keeper, [])
    |> Enum.reduce(ctx, fn {x, y}, acc ->
      summon_mob(acc,
        mob_id: 1933,
        map: "que_q#{sub}",
        at: {x, y},
        event: "#{keeper_name(sub, keeper)}::OnMyMobDead"
      )
    end)
  end

  defp keeper_identity(ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)

    keeper =
      Rathena.atoi(Rathena.charat(strnpcinfo(ctx, 2), Rathena.getstrlen(strnpcinfo(ctx, 2)) - 1))

    {ctx, sub, keeper}
  end

  defp keeper_name(sub, keeper), do: "Temple Keeper##{sub}_ac0#{keeper}"
end
