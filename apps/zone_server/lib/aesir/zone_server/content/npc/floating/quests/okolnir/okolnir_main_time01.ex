defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.OkolnirMainTime01 do
  @moduledoc """
  Resets access to Okolnir after its cooldown.

  ## Behavior

  - Tracks the cooldown and restores the quest NPCs when it expires.

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
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru01_time01"
      },
      %{
        map: "que_qaru02",
        x: 1,
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru02_time01"
      },
      %{
        map: "que_qaru03",
        x: 1,
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru03_time01"
      },
      %{
        map: "que_qaru04",
        x: 1,
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru04_time01"
      },
      %{
        map: "que_qaru05",
        x: 1,
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru05_time01"
      },
      %{
        map: "que_qsch01",
        x: 1,
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch01_time01"
      },
      %{
        map: "que_qsch02",
        x: 1,
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch02_time01"
      },
      %{
        map: "que_qsch03",
        x: 1,
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch03_time01"
      },
      %{
        map: "que_qsch04",
        x: 1,
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch04_time01"
      },
      %{
        map: "que_qsch05",
        x: 1,
        y: 6,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch05_time01"
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
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx |> set_local(:"sub$", sub) |> setd("$gqse_#{sub}_time", 0) |> initnpctimer()
  end

  def on_event("OnReset", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> setd("$siz_#{sub}_on", 0)
    |> setd("$gqse_#{sub}_time", 0)
    |> stopnpctimer()
  end

  def on_event("OnTimer3600000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)
    time_key = "$gqse_#{sub}_time"

    cond do
      getd(ctx, time_key) < 12 ->
        ctx |> setd(time_key, getd(ctx, time_key) + 1) |> initnpctimer()

      getd(ctx, time_key) == 12 ->
        ctx
        |> setd("$siz_#{sub}_on", 0)
        |> setd(time_key, 0)
        |> enablenpc("Wish Maiden#gq_#{sub}")
        |> enablenpc("Piamette##{sub}")
        |> hideoffnpc("Wish Maiden##{sub}_boss")
        |> stopnpctimer()

      true ->
        ctx
    end
  end

  def on_event("OnInit", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])
    ctx = set_local(ctx, :"sub$", sub)
    if getd(ctx, "$siz_#{sub}_on") == 2, do: initnpctimer(ctx), else: ctx
  end
end
