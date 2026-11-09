defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.NmsommainJin02 do
  @moduledoc """
  Controls the eastern magic formation's monster waves.

  ## Behavior

  - Announces and summons Bloody Hunter in timed waves.
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
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru01_jin02"
      },
      %{
        map: "que_qaru02",
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru02_jin02"
      },
      %{
        map: "que_qaru03",
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru03_jin02"
      },
      %{
        map: "que_qaru04",
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru04_jin02"
      },
      %{
        map: "que_qaru05",
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomaru05_jin02"
      },
      %{
        map: "que_qsch01",
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch01_jin02"
      },
      %{
        map: "que_qsch02",
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch02_jin02"
      },
      %{
        map: "que_qsch03",
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch03_jin02"
      },
      %{
        map: "que_qsch04",
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch04_jin02"
      },
      %{
        map: "que_qsch05",
        x: 275,
        y: 299,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nmsomsch05_jin02"
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
    initnpctimer(ctx)
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
    announcement = "The Eastern magic formation is working to summon Bloody Hunter."

    coordinates = [
      263,
      292,
      264,
      291,
      265,
      290,
      266,
      289,
      267,
      288,
      268,
      287,
      269,
      286,
      270,
      285,
      271,
      284,
      272,
      283,
      265,
      294,
      266,
      293,
      267,
      292,
      268,
      291,
      269,
      290,
      270,
      289,
      271,
      288,
      272,
      287,
      273,
      286,
      274,
      285,
      267,
      296,
      268,
      295,
      269,
      294,
      270,
      283,
      271,
      282,
      272,
      281,
      273,
      280,
      274,
      279,
      275,
      276,
      276,
      275
    ]

    ctx = mapannounce(ctx, map, announcement, 1, "0x4d4dff")
    ctx = set_local(ctx, :xy, coordinates)
    summon_wave(ctx, coordinates, sub)
  end

  def on_event("OnTimer25000", ctx), do: on_event("OnTimer120000", ctx)
  def on_event("OnTimer55000", ctx), do: on_event("OnTimer120000", ctx)
  def on_event("OnTimer85000", ctx), do: on_event("OnTimer120000", ctx)

  def on_event("OnTimer120000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    coordinates = [
      274,
      301,
      275,
      301,
      276,
      301,
      277,
      301,
      278,
      300,
      279,
      299,
      279,
      298,
      279,
      297,
      279,
      296,
      278,
      295,
      277,
      294,
      276,
      294,
      275,
      294,
      274,
      294,
      273,
      295,
      272,
      296,
      272,
      297,
      272,
      298,
      272,
      299,
      273,
      300
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
          mob_id: 1753,
          map: Rathena.concat("que_q", sub),
          at: {x, y},
          event: monster_event(sub)
        )

      set_local(acc, :i, get_local(acc, :i, 0) + 2)
    end)
  end

  defp monster_event(sub) do
    Rathena.concat(Rathena.concat("#nmsom", sub), "_jin02::OnMyMobDead")
  end
end
