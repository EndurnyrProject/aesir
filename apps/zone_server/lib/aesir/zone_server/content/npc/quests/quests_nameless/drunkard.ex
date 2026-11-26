defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Drunkard do
  @moduledoc """
  A drunk fisherman shares news about a mysterious boat.

  ## Behavior

  - Reveals a clue about the fisherman when the player reaches the appropriate quest stage.

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
        map: "ve_in",
        x: 239,
        y: 115,
        dir: 0,
        sprite: 943,
        name: "Drunkard",
        scope: :shared,
        unique_name: "Drunkard#Aru"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    cond do
      get_char_var(ctx, :aru_monas, 0) < 14 ->
        ctx
        |> mes("[Drunkard]")
        |> mes("Man, I feel great! Hah hah!")
        |> mes("Hey, gimme one more drink!")
        |> close()

      get_char_var(ctx, :aru_monas, 0) == 14 ->
        if get_char_var(ctx, :rachel_camel, 0) == 25 do
          ctx =
            ctx
            |> mes("[Drunkard]")
            |> mes("So--*Hic* What I was...")
            |> mes("Oog, dizzy... I say sayin',")
            |> mes("that guy that ^32CD32snuck out to")
            |> mes("sea on a boat^000000? You know")
            |> mes("*Hic* why he came back")
            |> mes("so early? You won't believe it!")
            |> next()
            |> mes("[Drunkard]")
            |> mes("Hah hah! He--*Hic*")
            |> mes("He thought he saw a ^DBDB70ghost^000000!")
            |> mes("Bwah hah hah! Oooog... Hey...")
            |> set_char_var(:aru_monas, 15)
            |> next()

          ctx
          |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
          |> mes("That's right!")
          |> mes("Maybe I should check")
          |> mes("on ^32CD32Kurdi's father since")
          |> mes("he's a fisherman^000000")
          |> close()
        else
          ctx |> mes("[Drunkard]") |> mes("Zzzz...") |> mes("Umm... Zzz...") |> close()
        end

      true ->
        ctx
        |> mes("[Drunkard]")
        |> mes("Why?! Why can't I take")
        |> mes("my boat out to sea? I hafta")
        |> mes("catch fish to make a living!")
        |> mes("What, they expect me to starve")
        |> mes("to death or something?! Huh?!")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end
end
