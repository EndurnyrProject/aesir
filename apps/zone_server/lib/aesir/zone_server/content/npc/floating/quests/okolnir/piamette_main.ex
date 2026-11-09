defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.PiametteMain do
  @moduledoc """
  Controls Piamette's encounter in Okolnir.

  ## Behavior

  - Announces and summons Piamette after the key keepers die.
  - Opens the southern paths when Piamette is defeated.

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
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_aru01"
      },
      %{
        map: "que_qaru02",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_aru02"
      },
      %{
        map: "que_qaru03",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_aru03"
      },
      %{
        map: "que_qaru04",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_aru04"
      },
      %{
        map: "que_qaru05",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_aru05"
      },
      %{
        map: "que_qsch01",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_sch01"
      },
      %{
        map: "que_qsch02",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_sch02"
      },
      %{
        map: "que_qsch03",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_sch03"
      },
      %{
        map: "que_qsch04",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_sch04"
      },
      %{
        map: "que_qsch05",
        x: 1,
        y: 4,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#piamette_sch05"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FOkolnir
  alias Aesir.ZoneServer.Script.Ctx

  @impl true
  @spec on_talk(Ctx.t()) :: Ctx.t()
  def on_talk(ctx), do: initnpctimer(ctx)

  @impl true
  @spec on_event(String.t(), Ctx.t()) :: Ctx.t()
  def on_event("OnEnable", ctx), do: initnpctimer(ctx)

  def on_event("OnReset", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> killmonster("que_q#{sub}", "#piamette_#{sub}::OnMyMobDead")
    |> stopnpctimer()
  end

  def on_event("OnTimer1000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> mapannounce(
      "que_q#{sub}",
      "Piamette : All the keeper of keys are dead now? Who freed my birds? Teo, who did it?",
      1,
      "0xdb7093"
    )
  end

  def on_event("OnTimer5000", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> mapannounce("que_q#{sub}", "Piamette : I'm pissed off now!", 1, "0xdb7093")
    |> disablenpc("Piamette##{sub}")
    |> summon_mob(
      mob_id: 1930,
      map: "que_q#{sub}",
      at: {131, 135},
      event: "#piamette_#{sub}::OnMyMobDead"
    )
    |> stopnpctimer()
  end

  def on_event("OnMyMobDead", ctx) do
    {ctx, sub} = FOkolnir.call(ctx, [])

    ctx
    |> set_local(:"sub$", sub)
    |> mapannounce(
      "que_q#{sub}",
      "Piamette has been released, so the warp gate toward the South is working now.",
      1,
      "0x00ff00"
    )
    |> enablenpc("windpath03_#{sub}")
    |> enablenpc("windpath04_#{sub}")
    |> donpcevent("#nm_switch_#{sub}::OnEnable")
  end
end
