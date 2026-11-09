defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.NmsommainJin01 do
  @moduledoc """
  Controls the western magic formation's monster waves.

  ## Behavior

  - Announces and summons Guard of Shadow in timed waves.
  - Removes the summoned monsters when disabled.

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
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru01_jin01"
      },
      %{
        map: "que_qaru02",
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru02_jin01"
      },
      %{
        map: "que_qaru03",
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru03_jin01"
      },
      %{
        map: "que_qaru04",
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru04_jin01"
      },
      %{
        map: "que_qaru05",
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru05_jin01"
      },
      %{
        map: "que_qsch01",
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch01_jin01"
      },
      %{
        map: "que_qsch02",
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch02_jin01"
      },
      %{
        map: "que_qsch03",
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch03_jin01"
      },
      %{
        map: "que_qsch04",
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch04_jin01"
      },
      %{
        map: "que_qsch05",
        x: 229,
        y: 297,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch05_jin01"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: on_event("OnEnable", ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)

    ctx
    |> donpcevent(Rathena.concat(Rathena.concat("#", sub), "_stone01::OnEnable"))
    |> initnpctimer()
  end

  def on_event("OnDisable", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)
    ctx |> killmonster(Rathena.concat("que_q", sub), monster_event(sub)) |> stopnpctimer()
  end

  def on_event("OnTimer5000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)
    map = Rathena.concat("que_q", sub)
    announcement = "The Western magic formation is working to summon Guard of Shadow."

    coordinates = [
      226,
      288,
      227,
      289,
      228,
      290,
      229,
      291,
      230,
      292,
      231,
      293,
      232,
      294,
      233,
      295,
      234,
      296,
      235,
      297,
      228,
      286,
      229,
      287,
      230,
      288,
      231,
      289,
      232,
      290,
      233,
      291,
      234,
      292,
      235,
      293,
      236,
      294,
      237,
      295,
      230,
      284,
      231,
      285,
      232,
      286,
      233,
      287,
      234,
      288,
      235,
      289,
      236,
      290,
      237,
      291,
      238,
      292,
      239,
      293
    ]

    ctx = set_local(ctx, :xy, coordinates)
    ctx = mapannounce(ctx, map, announcement, 1, "0x4d4dff")
    summon_wave(ctx, coordinates, sub)
  end

  def on_event("OnTimer25000", ctx), do: on_event("OnTimer120000", ctx)
  def on_event("OnTimer55000", ctx), do: on_event("OnTimer120000", ctx)
  def on_event("OnTimer85000", ctx), do: on_event("OnTimer120000", ctx)

  def on_event("OnTimer120000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    coordinates = [
      226,
      294,
      227,
      294,
      228,
      294,
      229,
      294,
      230,
      295,
      231,
      296,
      231,
      297,
      231,
      298,
      231,
      299,
      230,
      300,
      229,
      301,
      228,
      301,
      227,
      301,
      226,
      301,
      225,
      300,
      224,
      299,
      224,
      298,
      224,
      297,
      224,
      296,
      225,
      295
    ]

    ctx = ctx |> set_local(:"sub$", sub) |> set_local(:xy2, coordinates)
    summon_wave(ctx, coordinates, sub)
  end

  def on_event("OnTimer180000", ctx), do: stopnpctimer(ctx)
  def on_event("OnMyMobDead", ctx), do: ctx

  defp summon_wave(ctx, coordinates, sub) do
    ctx = set_local(ctx, :i, 0)

    coordinates
    |> Enum.chunk_every(2)
    |> Enum.reduce(ctx, fn [x, y], acc ->
      acc =
        summon_mob(acc,
          mob_id: 1752,
          map: Rathena.concat("que_q", sub),
          at: {x, y},
          event: monster_event(sub)
        )

      set_local(acc, :i, get_local(acc, :i, 0) + 2)
    end)
  end

  defp monster_event(sub) do
    Rathena.concat(Rathena.concat("#nmsom", sub), "_jin01::OnMyMobDead")
  end
end
