defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.MainCages do
  @moduledoc """
  Releases petrified players from Piamette's cages and disables the cage triggers.

  ## Behavior

  - Ends petrification and moves the entrant through the six cage exits in order.
  - Disables all six cages after a release and when the challenge initializes.

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
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru01_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru02_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru03_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru04_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru05_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch01_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch02_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch03_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch04_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 103,
        y: 153,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch05_cage01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru01_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru02_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru03_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru04_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru05_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch01_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch02_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch03_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch04_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 102,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch05_cage02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru01_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru02_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru03_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru04_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru05_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch01_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch02_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch03_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch04_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 113,
        y: 111,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch05_cage03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru01_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru02_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru03_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru04_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru05_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch01_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch02_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch03_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch04_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 161,
        y: 105,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch05_cage04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru01_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru02_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru03_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru04_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru05_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch01_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch02_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch03_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch04_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 168,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch05_cage05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru01_cage06",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru02_cage06",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru03_cage06",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru04_cage06",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#aru05_cage06",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch01_cage06",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch02_cage06",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch03_cage06",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch04_cage06",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 150,
        y: 159,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#sch05_cage06",
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
    {ctx, castle} = castle_context(ctx)

    ctx
    |> sc_end(:sc_stone)
    |> set_local(:n, [108, 151, 107, 135, 113, 114, 158, 106, 163, 133, 150, 154])
    |> set_local(:i, 0)
    |> leave_cages(castle)
    |> disable_cages(castle)
  end

  def on_event("OnInit", ctx) do
    {ctx, castle} = castle_context(ctx)
    disable_cages(ctx, castle)
  end

  defp castle_context(ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])
    {set_local(ctx, :"sub$", castle), castle}
  end

  defp leave_cages(ctx, castle) do
    ctx
    |> get_local(:n, [])
    |> Enum.chunk_every(2)
    |> Enum.reduce(ctx, fn [x, y], ctx ->
      ctx = warp(ctx, "que_q#{castle}", x, y)
      set_local(ctx, :i, get_local(ctx, :i, 0) + 2)
    end)
  end

  defp disable_cages(ctx, castle) do
    ctx = set_local(ctx, :i, 1)

    Enum.reduce(1..6, ctx, fn cage, ctx ->
      ctx
      |> disablenpc("##{castle}_cage0#{cage}")
      |> set_local(:i, cage + 1)
    end)
  end
end
