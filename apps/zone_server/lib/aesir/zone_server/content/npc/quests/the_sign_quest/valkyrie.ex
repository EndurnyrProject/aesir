defmodule Aesir.ZoneServer.Content.Npc.Quests.TheSignQuest.Valkyrie do
  @moduledoc """
  Guides the player through the Valkyrie's trial in The Sign quest.

  ## Behavior

  - Assigns the trial, provides guidance, and rewards its completion.
  - Restricts access for unchosen or banished visitors.

  ## Credits

  - Original from rAthena, authors and Contributors
    - SinSloth
    - MasterOfMuppets
    - Kargha
    - L0ne_W0lf
    - Kazukin
    - Kisuka
    - CalciumKid
    - tr0n
    - Euphy
    - Joseph
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script
  - LLM-assisted Elixir refactor reviewed by Cλstor
  """

  use Aesir.ZoneServer.Npc,
    scope: :shared,
    spawn: [
      %{
        map: "himinn",
        x: 48,
        y: 86,
        dir: 5,
        sprite: 811,
        name: "Valkyrie",
        scope: :shared,
        unique_name: "Valkyrie#sign"
      }
    ]

  alias Aesir.ZoneServer.Content.Npc.Functions.FUpdatesignvars
  alias Aesir.ZoneServer.Script.Rathena

  @impl true
  def on_talk(ctx) do
    {ctx, _} = FUpdatesignvars.call(ctx, [])
    ctx = mes(ctx, "[Valkyrie Sandra]")
    quest = get_char_var(ctx, :sign_q, 0)

    cond do
      quest < 81 ->
        dismiss(ctx)

      quest == 81 ->
        begin_trial(ctx)

      quest < 95 ->
        ctx
        |> mes("I commend your ability")
        |> mes("to survive in the realm")
        |> mes("of the dead. I imagine it")
        |> mes("must be very difficult for")
        |> mes("a mortal to endure its cruelty.")
        |> close()

      quest == 95 ->
        ctx
        |> mes("Regrettably, I can't really")
        |> mes("provide any answers for you.")
        |> mes("You must overcome the ordeals")
        |> mes(
          "of the gods on your own. All I can do is offer my guidance and prayer. ^FFFFFFcobo^000000"
        )
        |> next()
        |> mes("[Valkyrie Sandra]")
        |> mes("Remember that the")
        |> mes("demonstration of your belief,")
        |> mes("rather than the decision to")
        |> mes("blindly adhere to faith, is")
        |> mes("what the gods want to see.")
        |> next()
        |> mes("[Valkyrie Sandra]")
        |> mes("Always step forward")
        |> mes("with wisdom and courage.")
        |> mes("That is all I can tell you.")
        |> set_char_var(:sign_q, 96)
        |> close()

      quest in [129, 130] ->
        reward(ctx)

      quest < 150 ->
        ctx
        |> mes("The gods are watching")
        |> mes("you. Prove your courage,")
        |> mes("and at that moment, you")
        |> mes("will earn the honor of being")
        |> mes("selected by the gods.")
        |> close()

      quest > 199 and quest < 202 ->
        ctx
        |> mes("You have yet to")
        |> mes("fully prove your courage.")
        |> mes("Once you do, you will be")
        |> mes("summoned by the gods.")
        |> close()

      quest == 202 ->
        ctx
        |> mes("The gods are disappointed")
        |> mes("in what you have decided to")
        |> mes("do. Unfortunately, you have")
        |> mes("been banished from Valhalla")
        |> mes("and this place as well.")
        |> next()
        |> mes("[Valkyrie Sandra]")
        |> mes("Although you have failed,")
        |> mes("I hope that you find your")
        |> mes("another way to win back")
        |> mes("the favor of the gods...")
        |> set_char_var(:sign_q, 203)
        |> close()

      count_item(ctx, 7314) < 1 ->
        dismiss(ctx)

      true ->
        ctx
        |> mes("Great warrior,")
        |> mes("your time has not yet")
        |> mes("come. Please focus on")
        |> mes("your training until you")
        |> mes("are summoned by the gods...")
        |> close()
    end
  catch
    :throw, {:script_end, ctx} -> ctx
  end

  defp dismiss(ctx) do
    ctx
    |> mes("Only the chosen")
    |> mes("can enter this place.")
    |> mes("I will not ask how you've")
    |> mes("gained entrance, but I will")
    |> mes("require you to leave.")
    |> close2()
    |> warp("gef_fild07", 180, 242)
  end

  defp begin_trial(ctx) do
    {ctx, _} =
      ctx
      |> mes(Rathena.concat(Rathena.concat("Welcome, ", char_name(ctx, 0)), ","))
      |> mes("to this realm of holiness.")
      |> mes(
        "You have endured great difficulty and tested your courage to obtain the Sobbing Starlight, which will be the certificate for your test."
      )
      |> next()
      |> select(["Test...?"])

    ctx =
      ctx
      |> mes("[Valkyrie Sandra]")
      |> mes("The gods have decided that")
      |> mes("you are worthy of undergoing")
      |> mes("a special test that will judge")
      |> mes("your merits. If you are a true")
      |> mes("hero who is pure of heart,")
      |> mes("you will certainly succeed...")
      |> next()
      |> mes("[Valkyrie Sandra]")
      |> mes("Now, there is a critical")
      |> mes("situation in the ^FF0000realm where")
      |> mes("the fallen warriors dwell^000000. The")
      |> mes("gods wish for you to restore the balance by quelling a specific")
      |> mes("evil influence in that place.")
      |> next()
      |> mes("[Valkyrie Sandra]")
      |> mes("There will be many obstacles.")
      |> mes("First, the fallen, who will target their anger and hatred towards")
      |> mes("you. Where they have failed to")
      |> mes("enter Valhalla, you have a rare")
      |> mes("and wondrous opportunity...")
      |> next()
      |> mes("[Valkyrie Sandra]")
      |> mes("Secondly, and more")
      |> mes("importantly, you must find")
      |> mes("this evil influence on your")
      |> mes("own. This will judge your")
      |> mes("ability to discern good from evil. Do not trust appearances...")
      |> next()
      |> mes("[Valkyrie Sandra]")
      |> mes("This is your task.")
      |> mes("I cannot tell you more.")
      |> mes("It is now your duty to")
      |> mes("travel there and ferret")
      |> mes("out true darkness from")
      |> mes("one of the hearts there...")
      |> set_char_var(:sign_q, 82)
      |> percent_heal(hp: 100, sp: 100)

    renewal = Rathena.truthy?(checkre(ctx, 3))
    level = base_level(ctx)

    exp =
      cond do
        level < 56 -> 900
        level < 61 -> 1_200
        level < 66 -> 2_000
        level < 71 -> 3_500
        level < 76 -> 7_000
        level < 81 -> 12_000
        level < 86 -> 16_000
        level < 91 -> 21_000
        true -> 35_000
      end

    exp = if renewal, do: exp, else: exp * 10
    ctx |> getexp(exp, 0) |> close2() |> warp("geffen", 120, 100)
  end

  defp reward(ctx) do
    ctx =
      ctx
      |> mes("Welcome back.")
      |> mes(
        "Not only have you passed the trials that the gods have set for you, you have tested your courage in the realm of the dead and protected Midgard from attack."
      )
      |> next()
      |> mes("[Valkyrie Sandra]")
      |> mes(
        "I'm pleased to announce that the gods have been watching you and decided to invite you to Valhalla. However, Midgard still has great need of you."
      )
      |> next()
      |> mes("[Valkyrie Sandra]")
      |> mes(
        "As a symbol of this promise to invite you to Valhalla, you shall be rewarded with 'The Sign' which will show all others that you are a great warrior whose courage was tested by the gods themselves."
      )
      |> next()
      |> mes("[Valkyrie Sandra]")
      |> mes("Congratulations,")

    ctx
    |> mes(Rathena.concat(Rathena.concat("", char_name(ctx, 0)), ". Verily,"))
    |> mes("you are an honorable")
    |> mes("hero worthy of praise!")
    |> set_char_var(:sign_q, 137)
    |> give_item(7314, 1)
    |> close()
  end
end
