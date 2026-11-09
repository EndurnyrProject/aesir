defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.WindpathsMain do
  @moduledoc """
  Controls the paired Okolnir wind paths.

  ## Behavior

  - Disables both paths at initialization and transports players between them.

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
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_aru01",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_aru02",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_aru03",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_aru04",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_aru05",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_sch01",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_sch02",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_sch03",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_sch04",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 149,
        y: 105,
        dir: 0,
        sprite: 45,
        name: "windpath03_sch05",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_aru01",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_aru02",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_aru03",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_aru04",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_aru05",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_sch01",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_sch02",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_sch03",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_sch04",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 128,
        y: 104,
        dir: 0,
        sprite: 45,
        name: "windpath04_sch05",
        scope: :shared,
        trigger: {1, 1}
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
  def on_event("OnTouch_", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)
    map = "que_q#{get_local(ctx, :"sub$", "")}"

    if Rathena.truthy?(Rathena.compare(strnpcinfo(ctx, 0), "windpath03")) do
      warp(ctx, map, 119, 103)
    else
      warp(ctx, map, 146, 109)
    end
  end

  def on_event("OnInit", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)
    ctx = disablenpc(ctx, "windpath03_#{get_local(ctx, :"sub$", "")}")
    disablenpc(ctx, "windpath04_#{get_local(ctx, :"sub$", "")}")
  end
end
