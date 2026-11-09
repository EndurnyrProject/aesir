defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.Windpath01Main do
  @moduledoc """
  Controls the crystal key warp gate.

  ## Behavior

  - Consumes a Crystal Key to transport the player, or explains the requirement.

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
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_aru01",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_aru02",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_aru03",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_aru04",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_aru05",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_sch01",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_sch02",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_sch03",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_sch04",
        scope: :shared,
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 132,
        y: 172,
        dir: 0,
        sprite: 45,
        name: "windpath01_sch05",
        scope: :shared,
        trigger: {1, 1}
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnTouch_", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)

    if count_item(ctx, 7839) != 0 do
      ctx
      |> mes("The Warp Gate responds to the Crystal Key.")
      |> delitem(7839, 1)
      |> close()
      |> warp("que_q#{get_local(ctx, :"sub$", "")}", 114, 158)
    else
      ctx |> mes("You need the Crystal Key to activate the Warp Gate.") |> close()
    end
  end
end
