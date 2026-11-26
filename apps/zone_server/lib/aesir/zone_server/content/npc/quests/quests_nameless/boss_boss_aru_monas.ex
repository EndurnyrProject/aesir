defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.BossBossAruMonas do
  @moduledoc """
  A GM NPC inspects and adjusts quest progress.

  ## Behavior

  - Authorized players can inspect or set quest variables or apply preset values.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf
    - Koca
    - Yommy
    - brianluau
    - Euphy
    - Everade

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "sec_in02",
        x: 15,
        y: 15,
        dir: 4,
        sprite: 809,
        name: "boss",
        scope: :shared,
        unique_name: "boss_aru_monas"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = Functions.FGmNpc.call(ctx, [])

    {ctx, choice} =
      ctx
      |> mes("[Patch]")
      |> mes("Input.")
      |> next()
      |> select(["Now", "How much?", "P- How much?", "Others"])

    case choice do
      1 ->
        ctx = mes(ctx, " ")
        ctx |> mes(Rathena.concat("", get_char_var(ctx, :aru_monas, 0))) |> close()

      2 ->
        {ctx, raw_progress} = input(ctx, :int)
        {_, progress} = Rathena.input_int(raw_progress, 0, 1000)
        ctx = set_local(ctx, :input, progress)
        ctx = ctx |> set_char_var(:aru_monas, get_local(ctx, :input, 0)) |> mes(" ")
        ctx |> mes(Rathena.concat("", get_char_var(ctx, :aru_monas, 0))) |> close()

      3 ->
        {ctx, raw_curse} = input(ctx, :int)
        {_, curse} = Rathena.input_int(raw_curse, 0, 1000)
        ctx = set_local(ctx, :input, curse)
        ctx = ctx |> set_char_var(:prt_curse, get_local(ctx, :input, 0)) |> mes(" ")
        ctx |> mes(Rathena.concat("", get_char_var(ctx, :prt_curse, 0))) |> close()

      4 ->
        ctx
        |> set_char_var(:prt_curse, 61)
        |> set_char_var(:ra_tem_q, 12)
        |> set_char_var(:rachel_camel, 25)
        |> set_char_var(:lost_boy, 0)
        |> close()

      _ ->
        ctx
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
