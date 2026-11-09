defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.GuardOfShadow do
  @moduledoc """
  Turns Guard of Shadow ambush markers into monster reinforcements.

  ## Behavior

  - Hides the triggered marker and summons its Guard of Shadow reinforcements.
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
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru01_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru01",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru01_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru01",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru01_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru01",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru01_04",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru02_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru02_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru02_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru02",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru02_04",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru03_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru03_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru03_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru03",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru03_04",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru04_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru04_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru04_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru04",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru04_04",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru05_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru05_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru05_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qaru05",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#aru05_04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch01_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch01_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch01_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch01",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch01_04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch02_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch02_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch02_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch02",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch02_04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch03_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch03_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch03_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch03",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch03_04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch04_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch04_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch04_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch04",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch04_04",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 235,
        y: 285,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch05_01",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 224,
        y: 290,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch05_02",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 236,
        y: 296,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch05_03",
        trigger: {4, 4}
      },
      %{
        map: "que_qsch05",
        x: 225,
        y: 303,
        dir: 5,
        sprite: 1752,
        name: "Guard of Shadow",
        scope: :shared,
        unique_name: "Guard of Shadow#sch05_04",
        trigger: {4, 4}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  # One coordinate set per ambush, as x/y pairs. The ambush is picked by the last character of the
  # NPC name, which rAthena converts to its integer value when it stores it.
  @ambush_points %{
    1 => [234, 284, 235, 285, 236, 286],
    2 => [223, 289, 224, 290, 225, 291],
    3 => [235, 295, 236, 296, 237, 297],
    4 => [224, 302, 225, 303, 226, 304]
  }

  @ambushes [1, 2, 3, 4]

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
      disablenpc(ctx, "Guard of Shadow##{castle}_0#{ambush}")
    end)
  end

  defp summon_ambush(ctx, castle, name) do
    @ambush_points
    |> Map.get(ambush_index(ctx), [])
    |> Enum.chunk_every(2)
    |> Enum.reduce(ctx, fn [x, y], ctx ->
      summon_mob(ctx,
        mob_id: 1752,
        map: castle_map(castle),
        at: {x, y},
        event: "#{name}::OnMyMobDead"
      )
    end)
  end

  defp ambush_name(ctx, castle), do: "Guard of Shadow##{castle}_0#{ambush_index(ctx)}"

  defp ambush_index(ctx) do
    name = strnpcinfo(ctx, 2)
    Rathena.atoi(Rathena.charat(name, Rathena.getstrlen(name) - 1))
  end

  defp castle_map(castle), do: "que_q#{castle}"
end
