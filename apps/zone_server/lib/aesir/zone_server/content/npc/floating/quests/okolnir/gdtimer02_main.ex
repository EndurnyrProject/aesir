defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.Gdtimer02Main do
  @moduledoc """
  Controls the key keeper encounter in Okolnir.

  ## Behavior

  - Summons key keepers and releases Piamette when they are defeated.
  - Resets the cages and spell sequence if the encounter times out.

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
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_aru01"
      },
      %{
        map: "que_qaru02",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_aru02"
      },
      %{
        map: "que_qaru03",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_aru03"
      },
      %{
        map: "que_qaru04",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_aru04"
      },
      %{
        map: "que_qaru05",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_aru05"
      },
      %{
        map: "que_qsch01",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_sch01"
      },
      %{
        map: "que_qsch02",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_sch02"
      },
      %{
        map: "que_qsch03",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_sch03"
      },
      %{
        map: "que_qsch04",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_sch04"
      },
      %{
        map: "que_qsch05",
        x: 2,
        y: 3,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#gdtimer02_sch05"
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
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnStop", ctx), do: ctx |> stopnpctimer() |> kill_keepers()
  def on_event("OnReset", ctx), do: kill_keepers(ctx)

  def on_event("OnTimer4000", ctx) do
    announce(ctx, "Piamette : All of them are caught!")
  end

  def on_event("OnTimer8000", ctx) do
    announce(
      ctx,
      "Piamette : Let's call out the keeper of the key not to let the birds go far away."
    )
  end

  def on_event("OnTimer12000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    coords = [108, 151, 109, 135, 115, 116, 158, 106, 163, 133, 150, 154]

    ctx =
      ctx
      |> set_local(:"sub$", sub)
      |> mapannounce(
        "que_q#{sub}",
        "Piamette : The keeper of the key is protecting my cage.",
        1,
        "0xdb7093"
      )
      |> set_local(:xy, coords)
      |> set_local(:i, 0)

    coords
    |> Enum.chunk_every(2)
    |> Enum.with_index()
    |> Enum.reduce(ctx, fn {[x, y], index}, acc ->
      acc
      |> summon_mob(
        mob_id: 1905,
        map: "que_q#{sub}",
        at: {x, y},
        event: "#gdtimer02_#{sub}::OnMyMobDead"
      )
      |> set_local(:i, index * 2 + 2)
    end)
  end

  def on_event("OnTimer112000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> mapannounce(
      "que_q#{sub}",
      "Piamette : Whooping fun times are back! Now, Go! I'll get back to!!",
      1,
      "0xdb7093"
    )
    |> killmonster("que_q#{sub}", "#gdtimer02_#{sub}::OnMyMobDead")
    |> set_local(:i, 1)
    |> cages(sub, :enable)
    |> setd("$@gqse_#{sub}_gd", 0)
  end

  def on_event("OnTimer113000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> set_local(:i, 1)
    |> cages(sub, :disable)
    |> donpcevent("#gdtimer01_#{sub}::OnEnable")
    |> stopnpctimer()
  end

  def on_event("OnMyMobDead", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)

    if not Rathena.truthy?(mobcount(ctx, "que_q#{sub}", "#gdtimer02_#{sub}::OnMyMobDead")) do
      ctx
      |> set_local(:i, 1)
      |> cages(sub, :enable)
      |> donpcevent("#piamette_#{sub}::OnEnable")
      |> stopnpctimer()
    else
      ctx
    end
  end

  defp announce(ctx, message) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> set_local(:"sub$", sub) |> mapannounce("que_q#{sub}", message, 1, "0xdb7093")
  end

  defp kill_keepers(ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> set_local(:"sub$", sub) |> killmonster("que_q#{sub}", "#gdtimer02_#{sub}::OnMyMobDead")
  end

  defp cages(ctx, sub, action) do
    Enum.reduce(1..6, ctx, fn i, acc ->
      name = "##{sub}_cage0#{i}"
      acc = if action == :enable, do: enablenpc(acc, name), else: disablenpc(acc, name)
      set_local(acc, :i, i + 1)
    end)
  end
end
