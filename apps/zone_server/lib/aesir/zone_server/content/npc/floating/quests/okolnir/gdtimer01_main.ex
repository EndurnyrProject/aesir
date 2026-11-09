defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.Gdtimer01Main do
  @moduledoc """
  Controls the rotating spell and cage sequence in Okolnir.

  ## Behavior

  - Cycles the spell targets and resets cages when too few birds are captured.

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
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_aru01"
      },
      %{
        map: "que_qaru02",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_aru02"
      },
      %{
        map: "que_qaru03",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_aru03"
      },
      %{
        map: "que_qaru04",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_aru04"
      },
      %{
        map: "que_qaru05",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_aru05"
      },
      %{
        map: "que_qsch01",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_sch01"
      },
      %{
        map: "que_qsch02",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_sch02"
      },
      %{
        map: "que_qsch03",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_sch03"
      },
      %{
        map: "que_qsch04",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_sch04"
      },
      %{
        map: "que_qsch05",
        x: 2,
        y: 2,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer01_sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: ctx

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnStop", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = ctx |> set_local(:"sub$", sub) |> set_local(:i, 1)

    ctx =
      Enum.reduce(1..8, ctx, fn i, acc ->
        acc |> donpcevent("#getspell0#{i}_#{sub}::OnDisable") |> set_local(:i, i + 1)
      end)

    stopnpctimer(ctx)
  end

  def on_event("OnTimer1000", ctx), do: switch_spell(ctx, 8, 1)
  def on_event("OnTimer10000", ctx), do: switch_spell(ctx, 1, 2)
  def on_event("OnTimer20000", ctx), do: switch_spell(ctx, 2, 3)
  def on_event("OnTimer30000", ctx), do: switch_spell(ctx, 3, 4)
  def on_event("OnTimer40000", ctx), do: switch_spell(ctx, 4, 5)
  def on_event("OnTimer50000", ctx), do: switch_spell(ctx, 5, 6)
  def on_event("OnTimer60000", ctx), do: switch_spell(ctx, 6, 7)
  def on_event("OnTimer70000", ctx), do: switch_spell(ctx, 7, 8)

  def on_event("OnTimer75000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)
    key = "$@gqse_#{sub}_gd"

    if getd(ctx, key) < 6 do
      ctx
      |> mapannounce(
        "que_q#{sub}",
        "Piamette : Silly birds! Silly Teo! Why can't you put away the cage at once?!",
        1,
        "0x00ff00"
      )
      |> set_local(:i, 1)
      |> cages(sub, :enable)
      |> setd(key, 0)
    else
      ctx
    end
  end

  def on_event("OnTimer76000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> set_local(:"sub$", sub) |> set_local(:i, 1) |> cages(sub, :disable)
  end

  def on_event("OnTimer80000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> set_local(:"sub$", sub) |> donpcevent("#gdtimer01_#{sub}::OnEnable")
  end

  defp switch_spell(ctx, previous, next) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> donpcevent("#getspell0#{previous}_#{sub}::OnDisable")
    |> donpcevent("#getspell0#{next}_#{sub}::OnEnable")
  end

  defp cages(ctx, sub, action) do
    Enum.reduce(1..6, ctx, fn i, acc ->
      name = "##{sub}_cage0#{i}"
      acc = if action == :enable, do: enablenpc(acc, name), else: disablenpc(acc, name)
      set_local(acc, :i, i + 1)
    end)
  end
end
