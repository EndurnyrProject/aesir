defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsProntera.Prtcurse do
  @moduledoc """
  An investigator reviews clues about the royal curse.

  ## Behavior

  - At the appropriate quest stage, lets the player choose which lead to follow next.

  ## Credits

  - Original from rAthena, authors and Contributors
    - kobra_k88
    - L0ne_W0lf
    - Lupus
    - Silent
    - Evera
    - Samuray22
    - SinSloth
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
        map: "morocc",
        x: 45,
        y: 103,
        dir: 0,
        sprite: -1,
        name: "",
        scope: :shared,
        unique_name: "#prtcurse",
        trigger: {2, 2}
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_event("OnTouch", ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    ev_ontouch(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def ev_ontouch(ctx) do
    if get_char_var(ctx, :prt_curse, 0) == 25 do
      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Hm. I'd better review")
        |> mes("the facts I've learned so")
        |> mes("that I can better focus on")
        |> mes("this investigation. Let's see~")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Long ago, the giant serpent")
        |> mes("Jormungand threatened mankind.")
        |> mes("7 warriors defeated Jormungand, led by Tristram III of the Geoborg")
        |> mes("family, but Jormungand cursed the Geoborg bloodline in its defeat.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Ever since, the curse kills")
        |> mes("the first born prince of the")
        |> mes("Geoborg family at an early age.")
        |> mes("However, all of the princes of")
        |> mes("this generation were killed.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("According to what I've")
        |> mes("learned from that assassin,")
        |> mes("the first prince died from the")
        |> mes("curse, and the other two may")
        |> mes("have died from poisoning.")
        |> next()

      ctx =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("It's most likely that if")
        |> mes("poison was used, then the")
        |> mes("person who used it was an")
        |> mes("assassin from outside of the")
        |> mes("Rune-Midgarts Kingdom. Yes,")
        |> mes("that's about everything I know.")
        |> next()

      {ctx, choice} =
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Now, that historian Rodafrian")
        |> mes("has been waiting for me to tell")
        |> mes("her the lyrics of that song, but Father Bamph is also waiting")
        |> mes("for the info I've learned from the Assassin Guild. What should I do?")
        |> next()
        |> select(["Go to Rodafrian", "Go to Father Bamph"])

      if choice == 1 do
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Well, it's easier for me")
        |> mes("to visit Rodafrian now.")
        |> mes("She's much closer than")
        |> mes("Father Bamph, so I guess")
        |> mes("that I'll go talk to her first.")
        |> set_char_var(:prt_curse, 30)
        |> close()
      else
        ctx
        |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
        |> mes("Well, it's more important")
        |> mes("that I go see Father Bamph")
        |> mes("and investigate the princes'")
        |> mes("bodies. I better head over")
        |> mes("to Prontera right away.")
        |> set_char_var(:prt_curse, 50)
        |> close()
      end
    else
      ctx
    end
  end
end
