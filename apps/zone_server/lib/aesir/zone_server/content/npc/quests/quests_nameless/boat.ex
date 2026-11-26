defmodule Aesir.ZoneServer.Content.Npc.Quests.QuestsNameless.Boat do
  @moduledoc """
  A boat carries travelers to the monastery.

  ## Behavior

  - Larjes offers assistance on the first voyage; later trips depend on quest progress.

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
        map: "ve_fild07",
        x: 125,
        y: 128,
        dir: 0,
        sprite: 111,
        name: "Boat",
        scope: :shared,
        unique_name: "Boat#Aru"
      }
    ]

  @impl true
  def on_talk(ctx) do
    progress = get_char_var(ctx, :aru_monas, 0)

    cond do
      progress < 16 ->
        ctx
        |> mes("^3355FFThis boat seems to ")
        |> mes("be in decent condition.")
        |> mes("Who could its owner be?^000000")
        |> close()

      progress == 16 ->
        first_voyage(ctx)

      progress < 20 ->
        sail(ctx, "nameless_i")

      true ->
        sail(ctx, "nameless_n")
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp first_voyage(ctx) do
    ctx =
      ctx
      |> mes("^3355FFThis must be the boat that")
      |> mes("Karyn was talking about.")
      |> mes("It seems to be in pretty")
      |> mes("good shape. Now, the")
      |> mes("monastery should be")
      |> mes("southwest from here...^000000")
      |> next()
      |> hideoffnpc("Secret Agent#Aru")
      |> next()
      |> mes("[Larjes]")
      |> mes("Long time no see,")

    ctx = ctx |> mes("#{char_name(ctx, 0)}.") |> next()

    {ctx, choice} =
      ctx
      |> mes("[#{char_name(ctx, 0)}]")
      |> mes("Larjes!")
      |> next()
      |> mes("[Larjes]")
      |> mes("I had a tough time following")
      |> mes("you, you know? I actually")
      |> mes("almost lost you once. You")
      |> mes("must be wondering why")
      |> mes("I'm here. If you'll listen,")
      |> mes("I'll explain everything.")
      |> next()
      |> mes("[Larjes]")
      |> mes("According to our investigation, Arunafeltz is definitely involved")
      |> mes("in this case. We've been watching you since you're somehow related")
      |> mes("to that high ranked official from Arunafeltz. I apologize for that.")
      |> next()
      |> mes("[Larjes]")
      |> mes("This is an international")
      |> mes("incident, so to prevent any")
      |> mes("intel leaks to Arunafeltz,")
      |> mes("we've had to be much stricter")
      |> mes("with securing and protecting")
      |> mes("all information for this case.")
      |> next()
      |> mes("[Larjes]")
      |> mes("Anyway, I've decided to")
      |> mes("reveal myself to you since")
      |> mes("I'm the only one that can help")
      |> mes("you right now. You're thinking")
      |> mes("of using that boat, aren't you?")
      |> next()
      |> mes("[Larjes]")
      |> mes("If you don't have the skills,")
      |> mes("knowledge, and preparation")
      |> mes("to sail those waters ahead,")
      |> mes("you'll probably wreck the")
      |> mes("boat. You'll make it if you're lucky but... That's a lot of luck.")
      |> next()
      |> mes("[Larjes]")
      |> mes("I'll help you sail this")
      |> mes("boat to get where you're")
      |> mes("going. But if you fail, there's")
      |> mes("a chance you might have to")
      |> mes("sail this boat on your own if I'm not here. So, you ready to go?")
      |> next()
      |> select(["Yes, I'm ready.", "Give me more time."])

    case choice do
      1 ->
        ctx
        |> mes("[Larjes]")
        |> mes("Alright, let's go.")
        |> mes("Hold on to something:")
        |> mes("this will probably be")
        |> mes("a pretty rocky ride...")
        |> set_char_var(:aru_monas, 17)
        |> close2()
        |> hideonnpc("Secret Agent#Aru")
        |> warp("nameless_i", 257, 217)

      2 ->
        ctx
        |> mes("[Larjes]")
        |> mes("Alright. Just let me know")
        |> mes("whenever you're ready.")
        |> close()

      _ ->
        ctx
    end
  end

  defp sail(ctx, destination) do
    {ctx, choice} =
      ctx
      |> mes("^3355FFThis is the boat that")
      |> mes("can take you to the")
      |> mes("monastery.^000000")
      |> next()
      |> select(["Go to Monastery", "Cancel"])

    case choice do
      1 ->
        ctx
        |> mes("^3355FFYou set sail for")
        |> mes("the monastery...^000000")
        |> close2()
        |> warp(destination, 257, 217)

      2 ->
        ctx |> mes("^3355FFYou decide to") |> mes("stay ashore.^000000") |> close()

      _ ->
        ctx
    end
  end
end
