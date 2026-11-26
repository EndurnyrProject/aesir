defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Larjes259218 do
  @moduledoc """
  Larjes offers passage away from Nameless Island.

  ## Behavior

  - His conversation and transport offer depend on the player’s quest progress.

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
        map: "nameless_i",
        x: 259,
        y: 218,
        dir: 3,
        sprite: 97,
        name: "Larjes",
        scope: :shared,
        unique_name: "Larjes#Aru"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :aru_monas, 0)

    cond do
      progress < 18 ->
        ctx
        |> mes("[Larjes]")
        |> mes("I don't like this place.")
        |> mes("You'd be better be careful")
        |> mes("around here with those weird")
        |> mes("creatures running around.")
        |> close()

      progress < 24 ->
        {ctx, choice} =
          ctx
          |> mes("[Larjes]")
          |> mes("Good, you're back")
          |> mes("I know that there's still")
          |> mes("things on this island that")
          |> mes("you want to investigate,")
          |> mes("but did you want to leave")
          |> mes("this place for a while?")
          |> next()
          |> select(["Yes", "No"])

        if choice == 1 do
          depart(ctx, "Alight, let's go.")
        else
          stay(ctx, "Alright, but becareful.")
        end

      true ->
        {ctx, choice} =
          ctx
          |> mes("[Larjes]")
          |> mes("Did you still want to")
          |> mes("investigate the island?")
          |> next()
          |> select(["No", "Yes"])

        if choice == 1 do
          depart(ctx, "Alright, let's go.")
        else
          stay(ctx, "Alright, but be careful.")
        end
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp depart(ctx, message) do
    ctx
    |> mes("[Larjes]")
    |> mes(message)
    |> close2()
    |> warp("ve_fild07", 130, 130)
  end

  defp stay(ctx, message) do
    ctx
    |> mes("[Larjes]")
    |> mes(message)
    |> mes("Those creatures almost")
    |> mes("got you once, you know.")
    |> close()
  end
end
