defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Larjes0 do
  @moduledoc """
  Larjes helps the player leave Nameless Island and reports the king's fate.

  ## Behavior

  - Offers passage away from the island and accepts the king's token for experience.

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
        map: "nameless_n",
        x: 259,
        y: 218,
        dir: 3,
        sprite: 97,
        name: "Larjes",
        scope: :shared,
        unique_name: "Larjes#Boat1"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :aru_monas, 0) != 24 ->
        ask_to_leave(ctx, false)

      count_item(ctx, 7726) < 1 ->
        ask_to_leave(ctx, true)

      true ->
        report_king(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp ask_to_leave(ctx, returning?) do
    ctx =
      if returning? do
        ctx
        |> mes("[Larjes]")
        |> mes("Good, you're back.")
        |> mes("I know that there's still")
        |> mes("things on this island that")
        |> mes("you want to investigate,")
        |> mes("but did you want to leave")
        |> mes("this place for a while?")
      else
        ctx
        |> mes("[Larjes]")
        |> mes("Did you still want to")
        |> mes("investigate the island?")
      end

    options = if returning?, do: ["Yes", "No"], else: ["No", "Yes"]
    {ctx, choice} = ctx |> next() |> select(options)

    case {returning?, choice} do
      {true, 1} -> depart(ctx)
      {false, 1} -> depart(ctx)
      {true, 2} -> stay(ctx)
      {false, 2} -> stay(ctx)
      _ -> ctx
    end
  end

  defp depart(ctx) do
    ctx
    |> mes("[Larjes]")
    |> mes("Alright, let's go.")
    |> close2()
    |> warp("ve_fild07", 130, 130)
  end

  defp stay(ctx) do
    ctx
    |> mes("[Larjes]")
    |> mes("Alright, but becareful.")
    |> mes("Those creatures almost")
    |> mes("got you once, you know.")
    |> close()
  end

  defp report_king(ctx) do
    ctx =
      ctx
      |> mes("[Larjes]")
      |> mes("I don't believe it...")
      |> mes("That guy was Tristam III?!")
      |> mes("This explains a lot, I suppose.")
      |> mes("I'll report this along with the")
      |> mes("voucher. So Arunafeltz was")
      |> mes("behind that poison grass too...")
      |> next()
      |> mes("[Larjes]")
      |> mes("I'm shocked over this")
      |> mes("whole debacle. I'm sure")
      |> mes("the Rune-Midgarts royal family")
      |> mes("will be in an uproar over this.")
      |> mes("To think that we're involved")
      |> mes("in something this huge...")
      |> next()
      |> mes("[Larjes]")
      |> mes("Anyway, we better get")
      |> mes("going... This is huge!")
      |> delitem(7726, 1)
      |> set_char_var(:aru_monas, 25)

    ctx
    |> getexp(if(Rathena.truthy?(checkre(ctx, 3)), do: 100_000, else: 1_000_000), 0)
    |> close()
  end
end
