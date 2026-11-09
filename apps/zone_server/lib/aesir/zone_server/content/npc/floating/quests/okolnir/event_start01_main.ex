defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.EventStart01Main do
  @moduledoc """
  Runs Piamette's timed introduction in Okolnir.

  ## Behavior

  - Starts the encounter when a player enters the trigger.
  - Announces Piamette's dialogue and starts the next event.

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
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_aru01",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru02",
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_aru02",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru03",
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_aru03",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru04",
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_aru04",
        trigger: {1, 1}
      },
      %{
        map: "que_qaru05",
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_aru05",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch01",
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_sch01",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch02",
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_sch02",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch03",
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_sch03",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch04",
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_sch04",
        trigger: {1, 1}
      },
      %{
        map: "que_qsch05",
        x: 114,
        y: 158,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#event_start01_sch05",
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
  def on_event("OnEnable", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)
    enablenpc(ctx, "#event_start01_#{get_local(ctx, :"sub$", "")}")
  end

  def on_event("OnDisable", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)

    ctx
    |> disablenpc("#event_start01_#{get_local(ctx, :"sub$", "")}")
    |> stopnpctimer()
  end

  def on_event("OnTouch_", ctx) do
    {ctx, suffix} = ctx |> initnpctimer() |> FOkolnir.call([])
    ctx = set_local(ctx, :"sub$", suffix)
    disablenpc(ctx, "#event_start01_#{get_local(ctx, :"sub$", "")}")
  end

  def on_event("OnTimer2000", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)

    mapannounce(
      ctx,
      "que_q#{get_local(ctx, :"sub$", "")}",
      "Piamette mumblings : ..There were six birds, Teo. But one is....",
      1,
      "0xdb7093"
    )
  end

  def on_event("OnTimer6000", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)

    mapannounce(
      ctx,
      "que_q#{get_local(ctx, :"sub$", "")}",
      "Piamette mumblings : ...Shh.. Teo. The birds have returned..Are they birds that ran away before...? Or breakers who disguises themselves as good adventurers?",
      1,
      "0xdb7093"
    )
  end

  def on_event("OnTimer10000", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)

    mapannounce(
      ctx,
      "que_q#{get_local(ctx, :"sub$", "")}",
      "Piamette mumblings : Ha! They are caged in.",
      1,
      "0xdb7093"
    )
  end

  def on_event("OnTimer14000", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)

    ctx =
      mapannounce(
        ctx,
        "que_q#{get_local(ctx, :"sub$", "")}",
        "Piamette : Teo, Catch the birds! Put the cage away from here!",
        1,
        "0x00ff00"
      )

    ctx
    |> donpcevent("#gdtimer01_#{get_local(ctx, :"sub$", "")}::OnEnable")
    |> stopnpctimer()
  end

  def on_event("OnInit", ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", suffix)
    disablenpc(ctx, "#event_start01_#{get_local(ctx, :"sub$", "")}")
  end
end
