defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.BloodyHunter do
  @moduledoc """
  Turns Bloody Hunter ambush markers into monster reinforcements.

  ## Behavior

  - Hides the triggered marker and summons its Bloody Hunter reinforcements.
  - Clears each ambush on reset and disables its markers at initialization.

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
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru01_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru01",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru01_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru01",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru01_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru01",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru01_ac04",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru02_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru02_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru02_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru02_ac04",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru03_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru03_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru03_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru03_ac04",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru04_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru04_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru04_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru04_ac04",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru05_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru05_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru05_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#aru05_ac04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch01_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch01_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch01_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch01_ac04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch02_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch02_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch02_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch02_ac04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch03_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch03_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch03_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch03_ac04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch04_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch04_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch04_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch04_ac04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 266,
        y: 296,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch05_ac01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 271,
        y: 283,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch05_ac02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 270,
        y: 307,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch05_ac03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 279,
        y: 300,
        dir: 3,
        sprite: 1753,
        name: "Bloody Hunter",
        scope: :shared,
        unique_name: "Bloody Hunter#sch05_ac04",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  # The ambush is picked by the last character of the NPC name, which `charat` yields as a
  # string. The reference's switch has no `break`, so all four castles fall through to the
  # last coordinate set before the spawn loop runs.
  @ambushes [1, 2, 3, 4]
  @ambush_points [278, 301, 279, 300, 280, 299]

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])
    name = ambush_name(ctx, castle)

    ctx
    |> disablenpc(name)
    |> summon_ambush(castle, name)
  end

  def on_event("OnDisable", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])
    name = ambush_name(ctx, castle)

    ctx
    |> killmonster(castle_map(castle), "#{name}::OnMyMobDead")
    |> disablenpc(name)
  end

  def on_event("OnMyMobDead", ctx), do: ctx

  def on_event("OnInit", ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])

    Enum.reduce(@ambushes, ctx, fn ambush, ctx ->
      disablenpc(ctx, "Bloody Hunter##{castle}_ac0#{ambush}")
    end)
  end

  defp summon_ambush(ctx, castle, name) do
    if ambush_index(ctx) in @ambushes do
      @ambush_points
      |> Enum.chunk_every(2)
      |> Enum.reduce(ctx, fn [x, y], ctx ->
        summon_mob(ctx,
          mob_id: 1753,
          map: castle_map(castle),
          at: {x, y},
          event: "#{name}::OnMyMobDead"
        )
      end)
    else
      ctx
    end
  end

  defp ambush_name(ctx, castle), do: "Bloody Hunter##{castle}_ac0#{ambush_index(ctx)}"

  defp ambush_index(ctx) do
    name = strnpcinfo(ctx, 2)
    Rathena.atoi(Rathena.charat(name, Rathena.getstrlen(name) - 1))
  end

  defp castle_map(castle), do: "que_q#{castle}"
end
