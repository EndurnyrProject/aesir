defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsMoscovia.GrayWolf do
  @moduledoc """
  The Gray Wolf warns adventurers and recruits help against Koshei.

  ## Behavior

  - Quest progression controls his warnings, attacks, and transport.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Kisuka
    - brianluau
    - Gepard
    - L0ne_W0lf
    - Joseph
    - Euphy
    - Lemongrass
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "mosk_dun01",
        x: 167,
        y: 160,
        dir: 3,
        sprite: 972,
        name: "Gray Wolf",
        scope: :shared,
        unique_name: "Gray Wolf#rus03"
      }
    ]

  alias Aesir.ZoneServer.Script.Rathena
  @impl true
  def on_event("OnEnable", ctx) do
    ev_onenable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnTimer120000", ctx) do
    ev_ontimer120000(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnDisable", ctx) do
    ev_ondisable(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  def on_event("OnInit", ctx) do
    ev_oninit(ctx)
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  @impl true
  def on_talk(ctx) do
    case get_char_var(ctx, :rhea_rus_main, 0) do
      stage when stage < 2 -> turn_back(ctx)
      2 -> warn_adventurer(ctx)
      4 -> recruit_adventurer(ctx)
      _ -> ev_onenable(ctx)
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp turn_back(ctx) do
    ctx
    |> mes("[Gray Wolf]")
    |> mes("... Turn back, adventurer...")
    |> mes("This is not where you belong.")
    |> close2()
    |> warp("mosk_dun01", 190, 47)
  end

  defp warn_adventurer(ctx) do
    ctx =
      ctx
      |> mes("[Gray Wolf]")
      |> mes("Halt, adventurer.")
      |> mes("Why did you disregard the warnings on the stone?")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Are you the reason adventurers are getting lost around this forest?")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("...lost around this forest.")
      |> mes("He doesn't want anyone to wander around the forest.")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("He? Who is he?!")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("His name is Koshei, the Immortal...")
      |> mes(
        "and he has been freed from his captivity... You'd better leave before he finds you."
      )
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("I'm warning you again!")
      |> mes("Unless you want to be killed, leave now.")
      |> set_char_var(:rhea_rus_main, 3)

    ctx
    |> emotion(:huk, playerattached(ctx))
    |> specialeffect2(:hit2)
    |> percent_heal(hp: -50, sp: 0)
    |> next()
    |> mes("- The Gray Wolf attacks you -")
    |> mes("- with it's claws and jumps -")
    |> mes("- into the bushes behind you!! -")
    |> donpcevent("Gray Wolf#rus03::OnDisable")
    |> close2()
    |> warp("mosk_dun01", 190, 47)
  end

  defp recruit_adventurer(ctx) do
    ctx = ctx |> mes("[Gray Wolf]") |> mes("...Why did you come back?") |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("I am afraid of nothing!")
      |> mes("I'm not afraid of your warning 'cuz I'm not as weak as you think I am!")
      |> next()

    ctx =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes(
        "Your attack from before was a cheapshot! If you have something to do with the missing people around here, you won't be forgiven!"
      )
      |> mes("Come on!!!")
      |> next()
      |> mes("- You stand firm and -")
      |> mes("- aim your weapon -")
      |> mes("- at the Gray Wolf -")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("Stop it. You cannot beat me.")
      |> next()

    {ctx, choice} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
      |> mes("Let's see who's stronger?!")
      |> mes("Take your position. I won't take you by surprise!!!")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("......You...... Haha.....")
      |> mes("Hahahahaha!!")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("Yes, you are very brave.")
      |> mes("... Yes, I think that I've been waiting for someone like you.")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("Please accept my apologies.")
      |> next()
      |> mes("[Gray Wolf]")
      |> mes("I need brave adventurers, like you, to help me. Can you help me?")
      |> next()
      |> select(["No, how can I trust you?", "Ok, I'll help"])

    ctx =
      if choice == 1 do
        ctx
        |> mes("[Gray Wolf]")
        |> mes("Hu.. you won't. But, I ask you again. Can you help me?")
        |> next()
      else
        ctx
      end

    ctx
    |> mes(Rathena.concat(Rathena.concat("[", char_name(ctx, 0)), "]"))
    |> mes("... Ok, ok. There's no way I can refuse this type of request.")
    |> mes("So, what do you want me to do?")
    |> next()
    |> mes("[Gray Wolf]")
    |> mes("This isn't a good place to talk. Get on my back, I will show you something.")
    |> next()
    |> mes("- He turns his back to me -")
    |> mes("- I jump up and suddenly -")
    |> set_char_var(:rhea_rus_main, 5)
    |> donpcevent("Gray Wolf#rus03::OnDisable")
    |> close2()
    |> warp("mosk_dun01", 45, 257)
  end

  def ev_onenable(ctx) do
    ctx |> enablenpc("Gray Wolf#rus03") |> initnpctimer()
  end

  def ev_ontimer120000(ctx) do
    ev_ondisable(ctx)
  end

  def ev_ondisable(ctx) do
    ctx |> stopnpctimer() |> ev_oninit()
  end

  def ev_oninit(ctx) do
    disablenpc(ctx, "Gray Wolf#rus03")
  end
end
