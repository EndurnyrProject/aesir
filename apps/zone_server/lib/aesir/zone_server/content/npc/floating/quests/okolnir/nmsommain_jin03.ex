defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.NmsommainJin03 do
  @moduledoc """
  Controls the northern Okolnir summoning formation.

  ## Behavior

  - Announces and periodically summons temple keepers.
  - Removes remaining keepers when disabled.

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
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru01_jin03"
      },
      %{
        map: "que_qaru02",
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru02_jin03"
      },
      %{
        map: "que_qaru03",
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru03_jin03"
      },
      %{
        map: "que_qaru04",
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru04_jin03"
      },
      %{
        map: "que_qaru05",
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru05_jin03"
      },
      %{
        map: "que_qsch01",
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch01_jin03"
      },
      %{
        map: "que_qsch02",
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch02_jin03"
      },
      %{
        map: "que_qsch03",
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch03_jin03"
      },
      %{
        map: "que_qsch04",
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch04_jin03"
      },
      %{
        map: "que_qsch05",
        x: 251,
        y: 340,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch05_jin03"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: initnpctimer(ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnDisable", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> killmonster(Rathena.concat("que_q", sub), death_event(sub)) |> stopnpctimer()
  end

  def on_event("OnTimer5000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx =
      mapannounce(
        ctx,
        Rathena.concat("que_q", sub),
        "The Northern magic formation is working to summon Keeper of the Temple.",
        1,
        "0x4d4dff"
      )

    summon_keepers(ctx, sub, [
      {247, 329},
      {249, 329},
      {251, 329},
      {253, 329},
      {255, 329},
      {243, 339},
      {245, 337},
      {247, 335},
      {247, 333},
      {254, 333},
      {256, 335},
      {258, 337},
      {260, 339}
    ])
  end

  def on_event("OnTimer120000", ctx),
    do:
      summon_formation(ctx, [
        {251, 343},
        {252, 343},
        {255, 341},
        {255, 340},
        {254, 337},
        {253, 336},
        {250, 336},
        {249, 337},
        {248, 340},
        {248, 341}
      ])

  def on_event("OnTimer240000", ctx),
    do:
      summon_formation(ctx, [
        {250, 343},
        {252, 343},
        {254, 342},
        {255, 340},
        {255, 338},
        {253, 336},
        {250, 336},
        {248, 338},
        {248, 340},
        {249, 342}
      ])

  def on_event("OnTimer360000", ctx),
    do:
      ctx
      |> summon_formation([
        {250, 343},
        {252, 343},
        {254, 342},
        {255, 340},
        {255, 338},
        {253, 336},
        {251, 336},
        {249, 337},
        {248, 339},
        {248, 341}
      ])
      |> stopnpctimer()

  def on_event("OnMyMobDead", ctx), do: ctx

  defp summon_formation(ctx, positions) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    summon_keepers(ctx, sub, positions)
  end

  defp summon_keepers(ctx, sub, positions) do
    Enum.reduce(positions, ctx, fn at, acc ->
      summon_mob(acc,
        mob_id: 1933,
        map: Rathena.concat("que_q", sub),
        at: at,
        event: death_event(sub)
      )
    end)
  end

  defp death_event(sub), do: Rathena.concat(Rathena.concat("#nmsom", sub), "_jin03::OnMyMobDead")
end
