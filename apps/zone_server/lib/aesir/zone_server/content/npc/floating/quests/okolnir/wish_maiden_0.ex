defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.WishMaiden0 do
  @moduledoc """
  Stages the Wish Maiden boss encounter at the end of Okolnir.

  ## Behavior

  - Announces the confrontation before summoning the Wish Maiden.
  - Stops the trials and enables the reward NPC once the boss is defeated.
  - Hides the boss marker and clears the encounter on reset.

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
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru01_boss"
      },
      %{
        map: "que_qaru02",
        x: 251,
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru02_boss"
      },
      %{
        map: "que_qaru03",
        x: 251,
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru03_boss"
      },
      %{
        map: "que_qaru04",
        x: 251,
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru04_boss"
      },
      %{
        map: "que_qaru05",
        x: 251,
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#aru05_boss"
      },
      %{
        map: "que_qsch01",
        x: 251,
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch01_boss"
      },
      %{
        map: "que_qsch02",
        x: 251,
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch02_boss"
      },
      %{
        map: "que_qsch03",
        x: 251,
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch03_boss"
      },
      %{
        map: "que_qsch04",
        x: 251,
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch04_boss"
      },
      %{
        map: "que_qsch05",
        x: 251,
        y: 255,
        dir: 3,
        sprite: 1931,
        name: "Wish Maiden",
        scope: :shared,
        unique_name: "Wish Maiden#sch05_boss"
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
  def on_event("OnDisable", ctx) do
    ctx = identify_realm(ctx)
    suffix = get_local(ctx, :"sub$", "")

    ctx
    |> killmonster("que_q#{suffix}", "Wish Maiden##{suffix}_boss::OnMyMobDead")
    |> hideonnpc("Wish Maiden##{suffix}_boss")
    |> stopnpctimer()
  end

  def on_event("OnFight", ctx), do: initnpctimer(ctx)

  def on_event("OnTimer1000", ctx) do
    ctx
    |> identify_realm()
    |> announce_confrontation("Wish Maiden : You guys reached here.. Are your guardians dead...?")
  end

  def on_event("OnTimer4000", ctx) do
    ctx
    |> identify_realm()
    |> announce_confrontation("Wish Maiden : I sincerely welcome all your best efforts!")
  end

  def on_event("OnTimer5000", ctx) do
    ctx = identify_realm(ctx)
    suffix = get_local(ctx, :"sub$", "")

    ctx
    |> specialeffect(:icecrash)
    |> hideonnpc("Wish Maiden##{suffix}_boss")
    |> specialeffect(:sphere)
    |> summon_mob(
      mob_id: 1931,
      map: "que_q#{suffix}",
      at: {252, 340},
      event: "Wish Maiden##{suffix}_boss::OnMyMobDead"
    )
    |> stopnpctimer()
  end

  def on_event("OnMyMobDead", ctx) do
    ctx = identify_realm(ctx)
    suffix = get_local(ctx, :"sub$", "")

    if Rathena.truthy?(mobcount(ctx, "que_q#{suffix}", "Wish Maiden##{suffix}_boss::OnMyMobDead")) do
      ctx
    else
      ctx
      |> donpcevent("#okolnir_#{suffix}::OnStop")
      |> donpcevent("Wish Maiden##{suffix}_gift::OnEnable")
      |> announce_confrontation("Wish Maiden : ..Good, you deserve the Goddess' shine.")
    end
  end

  def on_event("OnInit", ctx) do
    ctx = identify_realm(ctx)
    hideonnpc(ctx, "Wish Maiden##{get_local(ctx, :"sub$", "")}_boss")
  end

  defp identify_realm(ctx) do
    {ctx, suffix} = FOkolnir.call(ctx, [])
    set_local(ctx, :"sub$", suffix)
  end

  defp announce_confrontation(ctx, message) do
    mapannounce(ctx, "que_q#{get_local(ctx, :"sub$", "")}", message, 1, "0x00ff00")
  end
end
