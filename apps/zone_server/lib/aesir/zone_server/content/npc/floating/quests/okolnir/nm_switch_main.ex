defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.NmSwitchMain do
  @moduledoc """
  Triggers the timed Okolnir guardian formations.

  ## Behavior

  - Announces the approaching encounter and activates its three formations.
  - Enables or disables the trigger when requested.

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
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_aru01",
        trigger: {5, 5}
      },
      %{
        map: "que_qaru02",
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_aru02",
        trigger: {5, 5}
      },
      %{
        map: "que_qaru03",
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_aru03",
        trigger: {5, 5}
      },
      %{
        map: "que_qaru04",
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_aru04",
        trigger: {5, 5}
      },
      %{
        map: "que_qaru05",
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_aru05",
        trigger: {5, 5}
      },
      %{
        map: "que_qsch01",
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_sch01",
        trigger: {5, 5}
      },
      %{
        map: "que_qsch02",
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_sch02",
        trigger: {5, 5}
      },
      %{
        map: "que_qsch03",
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_sch03",
        trigger: {5, 5}
      },
      %{
        map: "que_qsch04",
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_sch04",
        trigger: {5, 5}
      },
      %{
        map: "que_qsch05",
        x: 253,
        y: 273,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#nm_switch_sch05",
        trigger: {5, 5}
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
  def on_event("OnTouch_", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> disablenpc(Rathena.concat("#nm_switch_", sub)) |> initnpctimer()
  end

  def on_event("OnEnable", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    enablenpc(ctx, Rathena.concat("#nm_switch_", sub))
  end

  def on_event("OnDisable", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> disablenpc(Rathena.concat("#nm_switch_", sub)) |> stopnpctimer()
  end

  def on_event("OnTimer1000", ctx),
    do: announce(ctx, "Wish Maiden: Did you have a good time with Piamette?")

  def on_event("OnTimer4000", ctx),
    do:
      announce(
        ctx,
        "Wish Maiden: But it's the end. There will be summoned monsters coming soon..."
      )

  def on_event("OnTimer9000", ctx), do: announce(ctx, "Wish Maiden: So come here to me safely...")
  def on_event("OnTimer10000", ctx), do: enable_formation(ctx, "01")
  def on_event("OnTimer190000", ctx), do: enable_formation(ctx, "02")
  def on_event("OnTimer370000", ctx), do: ctx |> enable_formation("03") |> stopnpctimer()

  def on_event("OnInit", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    disablenpc(ctx, Rathena.concat("#nm_switch_", sub))
  end

  defp announce(ctx, message) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    mapannounce(ctx, Rathena.concat("que_q", sub), message, 1, "0x00ff00")
  end

  defp enable_formation(ctx, number) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> donpcevent(Rathena.concat(Rathena.concat("#nmsom", sub), "_jin#{number}::OnEnable"))
    |> donpcevent(Rathena.concat(Rathena.concat("#", sub), "_stone#{number}::OnEnable"))
  end
end
