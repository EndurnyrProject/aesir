defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.OrdinaryMan do
  @moduledoc """
  Larjes plays cards while waiting to speak with the player.

  ## Behavior

  - At the appropriate quest stage, he redirects the player to a private conversation.

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
        map: "cmd_in02",
        x: 174,
        y: 89,
        dir: 7,
        sprite: 97,
        name: "Ordinary Man",
        scope: :shared,
        unique_name: "Ordinary Man#pc1"
      }
    ]

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :aru_monas, 0) < 2 ->
        ctx
        |> mes("[Larjes]")
        |> mes("Damn it, I lost again!")
        |> mes("This game is rigged!")
        |> mes("No matter what I try,")
        |> mes("I can never seem to win!")
        |> mes("But Comodo Hold 'Em")
        |> mes("is so... It's so addicting!")
        |> close()

      get_char_var(ctx, :aru_monas, 0) == 2 ->
        {ctx, _} =
          ctx
          |> mes("[Larjes]")
          |> mes("Argh, I lost at this game")
          |> mes("so many times that I've")
          |> mes("completely lost track!")
          |> mes("I've got to win sometime...")
          |> next()
          |> select(["Excuse me."])

        {ctx, _} =
          ctx
          |> mes("[Larjes]")
          |> mes("Oh! Uh... Hmm...")
          |> mes("How may I help you?")
          |> next()
          |> select(["^6B8E23Priest Bamph^000000 sent me."])

        ctx
        |> mes("[Larjes]")
        |> mes("Oh, I see. I apologize")
        |> mes("if my screaming and yelling")
        |> mes("made you a bit uncomfortable.")
        |> mes("I'm just here to kill some")
        |> mes("time... I now see firsthand")
        |> mes("that gambling is truly evil!")
        |> next()
        |> mes("[Larjes]")
        |> mes("Er, would you come")
        |> mes("over this way? I don't")
        |> mes("want anyone else to")
        |> mes("overhear us talking.")
        |> close2()
        |> set_char_var(:aru_monas, 3)
        |> warp("cmd_in02", 110, 53)

      true ->
        ctx
        |> mes("[Larjes]")
        |> mes("What?! I lost again?")
        |> mes("How does... How does")
        |> mes("this game even work?!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
