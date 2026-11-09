defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.GetspellsMain do
  @moduledoc """
  Runs Piamette's petrifying spell traps and advances the six-cage challenge.

  ## Behavior

  - Enables or disables individual spell traps and marks enabled traps with a lock-on effect.
  - Petrifies entrants, moves them to the next cage, and announces each trapped bird's fate.
  - Switches the challenge timers when the sixth cage is reached.

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
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 113,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell01_sch05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 146,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell02_sch05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 131,
        y: 117,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell03_sch05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 117,
        y: 150,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell04_sch05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 150,
        y: 135,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell05_sch05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 117,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell06_sch05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 131,
        y: 154,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell07_sch05",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru01",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 146,
        y: 121,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#getspell08_sch05",
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
  def on_event("OnEnable", ctx) do
    {ctx, castle} = castle_context(ctx)
    spell = Rathena.atoi(Rathena.charat(strnpcinfo(ctx, 2), 9))

    ctx
    |> enablenpc("#getspell0#{spell}_#{castle}")
    |> specialeffect(:lockon)
  end

  def on_event("OnDisable", ctx) do
    {ctx, castle} = castle_context(ctx)
    spell = Rathena.atoi(Rathena.charat(strnpcinfo(ctx, 2), 9))
    disablenpc(ctx, "#getspell0#{spell}_#{castle}")
  end

  def on_event("OnTouch_", ctx) do
    {ctx, castle} = castle_context(ctx)
    ctx = sc_start(ctx, :sc_stone, 300_000, 0)
    progress = getd(ctx, "$@gqse_#{castle}_gd")

    ctx
    |> prepare_cage(progress, castle)
    |> enter_cage(castle)
  end

  def on_event("OnInit", ctx) do
    {ctx, castle} = castle_context(ctx)
    ctx = set_local(ctx, :i, 1)

    Enum.reduce(1..8, ctx, fn spell, ctx ->
      ctx
      |> disablenpc("#getspell0#{spell}_#{castle}")
      |> set_local(:i, spell + 1)
    end)
  end

  defp castle_context(ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])
    {set_local(ctx, :"sub$", castle), castle}
  end

  defp prepare_cage(ctx, 0, _castle) do
    set_local(ctx, :"n$", [
      "103",
      "153",
      "1",
      "Piamette : One white bird has dropped with its wing pierced by an arrow."
    ])
  end

  defp prepare_cage(ctx, 1, _castle) do
    set_local(ctx, :"n$", [
      "102",
      "135",
      "2",
      "Piamette : One bird is caught in a snare, and dropped into a lake."
    ])
  end

  defp prepare_cage(ctx, 2, _castle) do
    set_local(ctx, :"n$", [
      "113",
      "111",
      "3",
      "Piamette : One bird has died trapped in it's cage."
    ])
  end

  defp prepare_cage(ctx, 3, _castle) do
    set_local(ctx, :"n$", ["161", "105", "4", "Piamette : One bird was poisoned to death."])
  end

  defp prepare_cage(ctx, 4, _castle) do
    set_local(ctx, :"n$", [
      "168",
      "135",
      "5",
      "Piamette : One bird vomited blood while singing seven days and seven nights."
    ])
  end

  defp prepare_cage(ctx, 5, castle) do
    ctx
    |> set_local(:"n$", [
      "150",
      "159",
      "6",
      "Piamette : The last one broke her neck wriggling to get out of from it's eggshell!"
    ])
    |> donpcevent("#gdtimer02_#{castle}::OnEnable")
    |> donpcevent("#gdtimer01_#{castle}::OnStop")
  end

  defp prepare_cage(ctx, _progress, _castle), do: ctx

  defp enter_cage(ctx, castle) do
    ctx = disablenpc(ctx, "#getspell01_#{castle}")

    ctx =
      warp(
        ctx,
        "que_q#{castle}",
        Rathena.atoi(Enum.at(get_local(ctx, :"n$", []), 0, "")),
        Rathena.atoi(Enum.at(get_local(ctx, :"n$", []), 1, ""))
      )

    ctx =
      setd(
        ctx,
        "$@gqse_#{castle}_gd",
        Rathena.atoi(Enum.at(get_local(ctx, :"n$", []), 2, ""))
      )

    mapannounce(ctx, "que_q#{castle}", Enum.at(get_local(ctx, :"n$", []), 3, ""), 1, "0xFF0000")
  end
end
