defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.MazeManagerMain do
  @moduledoc """
  Controls the timed maze barriers.

  ## Behavior

  - Rotates the maze barriers and restarts the cycle.
  - Disables all barriers when the maze is stopped or initialized.

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
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_aru01"
      },
      %{
        map: "que_qaru02",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_aru02"
      },
      %{
        map: "que_qaru03",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_aru03"
      },
      %{
        map: "que_qaru04",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_aru04"
      },
      %{
        map: "que_qaru05",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_aru05"
      },
      %{
        map: "que_qsch01",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_sch01"
      },
      %{
        map: "que_qsch02",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_sch02"
      },
      %{
        map: "que_qsch03",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_sch03"
      },
      %{
        map: "que_qsch04",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_sch04"
      },
      %{
        map: "que_qsch05",
        x: 1,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#Maze_Manager_sch05"
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
    ctx |> set_local(:"sub$", sub) |> initnpctimer()
  end

  def on_event("OnDisable", ctx), do: ctx |> disable_barriers() |> stopnpctimer()
  def on_event("OnTimer1000", ctx), do: barrier_event(ctx, "rf", "OnDisable")
  def on_event("OnTimer2000", ctx), do: barrier_event(ctx, "yf", "OnDisable")
  def on_event("OnTimer3000", ctx), do: barrier_event(ctx, "bf", "OnEnable")
  def on_event("OnTimer120000", ctx), do: barrier_event(ctx, "bf", "OnDisable")
  def on_event("OnTimer121000", ctx), do: barrier_event(ctx, "yf", "OnDisable")
  def on_event("OnTimer123000", ctx), do: barrier_event(ctx, "rf", "OnEnable")
  def on_event("OnTimer240000", ctx), do: barrier_event(ctx, "bf", "OnDisable")
  def on_event("OnTimer241000", ctx), do: barrier_event(ctx, "rf", "OnDisable")
  def on_event("OnTimer242000", ctx), do: barrier_event(ctx, "yf", "OnEnable")

  def on_event("OnTimer360000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)
    donpcevent(ctx, Rathena.concat(Rathena.concat("#Maze_Manager_", sub), "::OnEnable"))
  end

  def on_event("OnInit", ctx), do: disable_barriers(ctx)

  defp barrier_event(ctx, barrier, event) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)
    donpcevent(ctx, Rathena.concat(Rathena.concat("#miro_#{barrier}_", sub), "::#{event}"))
  end

  defp disable_barriers(ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)

    Enum.reduce(["bf", "rf", "yf"], ctx, fn barrier, acc ->
      donpcevent(acc, Rathena.concat(Rathena.concat("#miro_#{barrier}_", sub), "::OnDisable"))
    end)
  end
end
