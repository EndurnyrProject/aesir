defmodule Aesir.ZoneServer.Content.Npc.Floating.Quests.Okolnir.OkolnirMain do
  @moduledoc """
  Coordinates the one-hour Okolnir challenge and its closing sequence.

  ## Behavior

  - Enables the challenge gates, maze, monsters, and guardians.
  - Announces the remaining time and disables the encounters when time expires.
  - Resets challenge progress and returns everyone to the castle after the closing warnings.

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
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru01"
      },
      %{
        map: "que_qaru02",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru02"
      },
      %{
        map: "que_qaru03",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru03"
      },
      %{
        map: "que_qaru04",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru04"
      },
      %{
        map: "que_qaru05",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_aru05"
      },
      %{
        map: "que_qsch01",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch01"
      },
      %{
        map: "que_qsch02",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch02"
      },
      %{
        map: "que_qsch03",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch03"
      },
      %{
        map: "que_qsch04",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch04"
      },
      %{
        map: "que_qsch05",
        x: 1,
        y: 1,
        dir: 0,
        sprite: 844,
        name: "",
        scope: :shared,
        unique_name: "#okolnir_sch05"
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
    {ctx, castle} = castle_context(ctx)

    ctx
    |> donpcevent("Gate01#gq_#{castle}::OnEnable")
    |> donpcevent("#Maze_Manager_#{castle}::OnEnable")
    |> donpcevent("#event_start01_#{castle}::OnEnable")
    |> donpcevent("#gd_#{castle}_mobctrl::OnEnable")
    |> enablenpc("Guard of Shadow##{castle}_01")
    |> enablenpc("Guard of Shadow##{castle}_02")
    |> enablenpc("Guard of Shadow##{castle}_03")
    |> enablenpc("Guard of Shadow##{castle}_04")
    |> enablenpc("Bloody Hunter##{castle}_ac01")
    |> enablenpc("Bloody Hunter##{castle}_ac02")
    |> enablenpc("Bloody Hunter##{castle}_ac03")
    |> enablenpc("Bloody Hunter##{castle}_ac04")
    |> enablenpc("Temple Keeper##{castle}_ac01")
    |> enablenpc("Temple Keeper##{castle}_ac02")
    |> initnpctimer()
  end

  def on_event("OnDisable", ctx) do
    {ctx, castle} = castle_context(ctx)

    ctx
    |> disable_encounters(castle)
    |> reset_progress(castle)
    |> stopnpctimer()
  end

  def on_event("OnStop", ctx), do: stopnpctimer(ctx)

  def on_event("OnTimer1000", ctx) do
    announce_on_castle(
      ctx,
      "Wish Maiden : Do your best, Okolnir will disappear in one hour!",
      "0x00ff00"
    )
  end

  def on_event("OnTimer1800000", ctx) do
    announce_on_castle(ctx, "Okolnir will disappear in 30 minutes.", "0xff0000")
  end

  def on_event("OnTimer2400000", ctx) do
    announce_on_castle(ctx, "Okolnir will disappear in 20 minutes.", "0xff0000")
  end

  def on_event("OnTimer3000000", ctx) do
    announce_on_castle(ctx, "Okolnir will disappear in 10 minutes.", "0xff0000")
  end

  def on_event("OnTimer3300000", ctx) do
    announce_on_castle(ctx, "Okolnir will disappear in 5 minutes.", "0xff0000")
  end

  def on_event("OnTimer3360000", ctx) do
    announce_on_castle(ctx, "Okolnir will disappear in 4 minutes.", "0xff0000")
  end

  def on_event("OnTimer3420000", ctx) do
    announce_on_castle(ctx, "Okolnir will disappear in 3 minutes.", "0xff0000")
  end

  def on_event("OnTimer3480000", ctx) do
    announce_on_castle(ctx, "Okolnir will disappear in 2 minutes.", "0xff0000")
  end

  def on_event("OnTimer3540000", ctx) do
    announce_on_castle(ctx, "Okolnir will disappear in 1 minutes.", "0xff0000")
  end

  def on_event("OnTimer3600000", ctx) do
    {ctx, castle} = castle_context(ctx)

    ctx
    |> mapannounce("que_q#{castle}", "Okolnir has begun to disappear.", 1, "0x4d4dff")
    |> disable_encounters(castle)
  end

  def on_event("OnTimer3605000", ctx) do
    announce_on_castle(
      ctx,
      "Wish Maiden: ... You will fall into a deep sleep within Okolnir... ",
      "0x00ff00"
    )
  end

  def on_event("OnTimer3608000", ctx) do
    announce_on_castle(
      ctx,
      "Wish Maiden: ..Have courage ... and await your chance again... ",
      "0x00ff00"
    )
  end

  def on_event("OnTimer3610000", ctx) do
    {ctx, castle} = castle_context(ctx)
    ctx = reset_progress(ctx, castle)
    mapwarp(ctx, "que_q#{castle}", to_string(strnpcinfo(ctx, 4)), 157, 369)
  end

  def on_event("OnTimer3611000", ctx) do
    {ctx, castle} = castle_context(ctx)

    ctx
    |> donpcevent("#okolnir_#{castle}_time01::OnEnable")
    |> stopnpctimer()
  end

  defp castle_context(ctx) do
    {ctx, castle} = FOkolnir.call(ctx, [])
    {set_local(ctx, :"sub$", castle), castle}
  end

  defp announce_on_castle(ctx, message, color) do
    {ctx, castle} = castle_context(ctx)
    mapannounce(ctx, "que_q#{castle}", message, 1, color)
  end

  defp disable_encounters(ctx, castle) do
    ctx
    |> disablenpc("Wish Maiden#gq_#{castle}")
    |> donpcevent("#gq_miromob2_#{castle}::OnReset")
    |> disablenpc("Piamette##{castle}")
    |> donpcevent("#gdtimer01_#{castle}::OnStop")
    |> donpcevent("#gdtimer02_#{castle}::OnStop")
    |> donpcevent("#piamette_#{castle}::OnReset")
    |> donpcevent("Wish Maiden##{castle}_boss::OnDisable")
    |> donpcevent("Wish Maiden##{castle}_gift::OnDisable")
    |> donpcevent("#gd_#{castle}_mobctrl::OnReset")
    |> donpcevent("Gate01#gq_#{castle}::OnDisable")
    |> donpcevent("#Maze_Manager_#{castle}::OnDisable")
    |> donpcevent("#event_start01_#{castle}::OnDisable")
    |> donpcevent("#nm_switch_#{castle}::OnDisable")
    |> donpcevent("#nmsom#{castle}_jin01::OnDisable")
    |> donpcevent("#nmsom#{castle}_jin02::OnDisable")
    |> donpcevent("#nmsom#{castle}_jin03::OnDisable")
    |> donpcevent("Guard of Shadow##{castle}_01::OnDisable")
    |> donpcevent("Guard of Shadow##{castle}_02::OnDisable")
    |> donpcevent("Guard of Shadow##{castle}_03::OnDisable")
    |> donpcevent("Guard of Shadow##{castle}_04::OnDisable")
    |> donpcevent("Bloody Hunter##{castle}_ac01::OnDisable")
    |> donpcevent("Bloody Hunter##{castle}_ac02::OnDisable")
    |> donpcevent("Bloody Hunter##{castle}_ac03::OnDisable")
    |> donpcevent("Bloody Hunter##{castle}_ac04::OnDisable")
    |> donpcevent("Temple Keeper##{castle}_ac01::OnDisable")
    |> donpcevent("Temple Keeper##{castle}_ac02::OnDisable")
    |> disablenpc("#to_agit_#{castle}_gate")
    |> donpcevent("##{castle}_stone01::OnReset")
    |> donpcevent("##{castle}_stone02::OnReset")
    |> donpcevent("##{castle}_stone03::OnReset")
    |> disablenpc("##{castle}_cage01")
    |> disablenpc("##{castle}_cage02")
    |> disablenpc("##{castle}_cage03")
    |> disablenpc("##{castle}_cage04")
    |> disablenpc("##{castle}_cage05")
    |> disablenpc("##{castle}_cage06")
    |> disablenpc("windpath03_#{castle}")
    |> disablenpc("windpath04_#{castle}")
  end

  defp reset_progress(ctx, castle) do
    ctx
    |> setd("$@gqse_#{castle}_miro", 0)
    |> setd("$@gqse_#{castle}_pcc", 0)
    |> setd("$@gqse_#{castle}_gd", 0)
    |> setd("$@gqse_#{castle}_nm", 0)
  end
end
